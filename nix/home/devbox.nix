# Devbox: headless. Layered on top of default.nix + linux.nix.
#
# Inherits the Linux base -- the SSSD/NSS compat shim and the zsh login-shell
# setup -- but deliberately NOT linux-desktop.nix, so no GUI apps (ghostty,
# zed, bitwarden), no nixGL, and no GNOME/XDG desktop integration. Keep this
# file for devbox-only differences; anything shared belongs in default.nix
# (cross-platform) or linux.nix (all Linux hosts).
#
# Build/switch:
#   home-manager switch --flake .#madhu-devbox
# (No --impure needed here: nothing in this path probes host GPU hardware.)

{ config, pkgs, lib, system, flox, ... }:

let
  floxPkg = flox.packages.${system}.default;
in

{
  # Devbox-only packages. Inherited packages come from default.nix and linux.nix.
  home.packages = [
    # Not pkgs.flox -- flox is not in nixpkgs. Comes from the flake input, which
    # flake.nix keeps on its own nixpkgs pin on purpose (see the comment there).
    floxPkg
  ];

  # direnv, with nix-direnv's caching so `use flake` does not re-evaluate on
  # every cd. Pairs with flox, which drives its environments through direnv.
  # enableZshIntegration defaults on, so the hook is installed already.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Opt out of flox's usage metrics.
  #
  # Done by invoking flox rather than writing ~/.config/flox/flox.toml from the
  # store, because flox owns that file: it rewrites it for trusted_environments,
  # auto_activate_environments and the FloxHub token. A home.file symlink there
  # gets *replaced* by a regular file on flox's first write (verified), which
  # then collides with the next activation. Letting flox make the edit keeps the
  # file flox's and the TOML valid.
  home.activation.floxDisableMetrics = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${floxPkg}/bin/flox config -l 2>/dev/null | grep -q '^disable_metrics = true'; then
      $DRY_RUN_CMD ${floxPkg}/bin/flox config --set disable_metrics true
    fi
  '';

  # flox ships prebuilt binaries in its own cache and nothing else; none of it is
  # on cache.nixos.org. Without this the activation package needs ~1200
  # derivations built from source (flox is a Rust workspace with its own
  # toolchain pin), instead of a download.
  #
  # This is only the user half. Substituters named by an untrusted user are
  # ignored, and this box has trusted-users = root, so it does nothing until
  # root also declares the cache trusted in /etc/nix/nix.conf:
  #
  #   extra-trusted-substituters = https://cache.flox.dev
  #   extra-trusted-public-keys = flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=
  #
  # followed by `systemctl restart nix-daemon`. The key is pinned in both halves,
  # so paths are signature-checked regardless of which side names the cache.
  # Written directly rather than through home-manager's nix.settings: that
  # module asserts nix.package is set, which would install a second nix into the
  # profile next to the daemon's. One line of config is not worth that.
  #
  # Only extra-substituters belongs here. The matching public key is a
  # restricted setting, so naming it as a non-trusted user does nothing except
  # emit "ignoring the client-specified setting 'trusted-public-keys'" on every
  # single nix invocation -- root already declares it in /etc/nix/nix.conf,
  # which is what actually signature-checks the paths.
  home.file.".config/nix/nix.conf".text = ''
    extra-substituters = https://cache.flox.dev
  '';

  programs.zsh.sessionVariables = {
    # No GUI here, so zed (default.nix's EDITOR) does not exist -- use helix.
    # default.nix derives jj's ui.editor from this same value, so `jj describe`
    # and friends follow automatically.
    EDITOR = lib.mkForce "hx";

    # Plannotator serves its review UI over HTTP. This host is only ever
    # reached over SSH, so the port has to be forwarded -- pin it instead of
    # taking the random local-mode port, so a single
    # `ssh -L 19432:localhost:19432` works for every session. 19432 is
    # plannotator's own remote-mode default; setting it explicitly means it
    # holds even when the SSH env vars are missing (tmux, cron, a detached
    # shell) and plannotator would otherwise fall back to local mode.
    PLANNOTATOR_PORT = "19432";

    # Goes with the pinned port: plannotator infers remote mode from SSH_TTY /
    # SSH_CONNECTION, which are absent in exactly those detached shells, and a
    # fixed port *without* remote mode is the documented failure -- the server
    # comes up on the right port, but plannotator then tries to open a browser
    # that does not exist here and appears to hang. Forcing it prints the URL
    # instead.
    PLANNOTATOR_REMOTE = "1";
  };

  # SSH_AUTH_SOCK: linux-desktop.nix pins it to the Bitwarden app's agent
  # socket, but this host does not import that layer -- devbox uses an agent
  # forwarded over SSH, so the value has to be discovered per login instead.
  #
  # Agent forwarding mints a fresh socket for each SSH login
  # (/tmp/ssh-XXXXXX/agent.N) and tears it down when that login ends. tmux
  # sessions outlive the login that started them, so every reconnect leaves
  # their SSH_AUTH_SOCK pointing at a socket that no longer exists. With
  # signing.behavior = "force" in the jj config, that surfaces as jj refusing to
  # write *any* commit ("No private key found for public key ..."), which reads
  # like a signing misconfiguration rather than a dead socket.
  #
  # tmux already tracks the current socket for us: SSH_AUTH_SOCK is in its
  # update-environment list, so attaching a client refreshes the *session*
  # environment. What it cannot do is reach into shells that are already
  # running. So pull from the session environment at each prompt.
  #
  # The tempting alternative -- a stable symlink at a fixed path, re-aimed on
  # login -- is a trap here. Sockets stay in /tmp either way, the pi nono pack
  # grants /tmp write via group:system_write_linux, and connecting to a unix
  # socket needs write. So any socket under /tmp is reachable from a sandbox
  # that knows its path, and an explicit filesystem.deny cannot override it
  # ("deny ... overlaps allowed parent '/tmp'"). The only thing keeping a
  # sandboxed agent off the forwarded socket is that the path is unguessable
  # (random per login) and /tmp is not listable in there. A fixed symlink
  # trades that away for convenience; keeping the random path costs nothing.
  programs.zsh.initContent = ''
    # Re-read SSH_AUTH_SOCK from tmux, which refreshes it on every client
    # attach. Cheap: one tmux round-trip per prompt, and a no-op when unchanged.
    if [ -n "$TMUX" ]; then
      _refresh_ssh_auth_sock() {
        local v
        v=$(command tmux show-environment SSH_AUTH_SOCK 2>/dev/null) || return
        v=''${v#SSH_AUTH_SOCK=}
        if [ -S "$v" ] && [ "$v" != "$SSH_AUTH_SOCK" ]; then
          export SSH_AUTH_SOCK="$v"
        fi
      }
      precmd_functions+=(_refresh_ssh_auth_sock)
    fi
  '';
}

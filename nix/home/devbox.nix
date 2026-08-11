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

{ config, pkgs, lib, ... }:

{
  # Devbox-only packages. Inherited packages come from default.nix and linux.nix.
  home.packages = with pkgs; [
  ];

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

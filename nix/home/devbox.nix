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

  # SSH_AUTH_SOCK is deliberately left unset: it is set only in
  # linux-desktop.nix (pointing at the Bitwarden app's agent socket), which
  # this host does not import. Devbox uses an agent forwarded over SSH.
}

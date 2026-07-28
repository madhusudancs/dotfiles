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

  # No GUI here, so zed (default.nix's EDITOR) does not exist -- use helix.
  # default.nix derives jj's ui.editor from this same value, so `jj describe`
  # and friends follow automatically.
  programs.zsh.sessionVariables.EDITOR = lib.mkForce "hx";

  # SSH_AUTH_SOCK is deliberately left unset: it is set only in
  # linux-desktop.nix (pointing at the Bitwarden app's agent socket), which
  # this host does not import. Devbox uses an agent forwarded over SSH.
}

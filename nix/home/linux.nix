# Linux base -- applies to every Linux host, headless or graphical.
#
# Anything that needs a display stack (GUI apps, nixGL wrappers, GNOME/XDG
# desktop-entry plumbing, fontconfig, gnome-keyring, the Bitwarden SSH agent)
# lives in linux-desktop.nix instead, so headless hosts can inherit this file
# without pulling in a desktop. See flake.nix for which hosts get which.

{ config, pkgs, lib, ... }:

{
  home.username = "madhu";
  home.homeDirectory = "/home/madhu";

  # ── NSS compat: let nix binaries resolve this SSSD/AD account ─────────────
  # This host's account lives only in SSSD (no /etc/passwd entry), and nix's own
  # glibc cannot dlopen the host's libnss_sss.so.2, so every nix-built program
  # that calls getpwuid()/getpwnam() fails to find the user. Node throws
  # `ERR_SYSTEM_ERROR: uv_os_get_passwd returned ENOENT` from os.userInfo(),
  # which is what broke `remote-pi install` (pi extension, daemon/install.js).
  # Exposing only that one host NSS module keeps nix's glibc in charge of libc
  # itself -- putting /usr/lib/x86_64-linux-gnu on LD_LIBRARY_PATH instead makes
  # nix binaries load the older host libc and die on GLIBC_ABI_GNU2_TLS.
  home.activation.nssCompat = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/lib/nss-compat"
    run ln -sfn /lib/x86_64-linux-gnu/libnss_sss.so.2 \
      "$HOME/.local/lib/nss-compat/libnss_sss.so.2"
  '';

  # .zshenv, so it also covers non-interactive zsh and anything it spawns
  # (ghostty launches zsh directly, so ~/.bashrc is never read here).
  programs.zsh.envExtra = ''
    case ":$LD_LIBRARY_PATH:" in
      *":$HOME/.local/lib/nss-compat:"*) ;;
      *) export LD_LIBRARY_PATH="$HOME/.local/lib/nss-compat''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
  '';

  # ── Login shell ───────────────────────────────────────────────────────────

  home.activation.chshToZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _zsh="${pkgs.zsh}/bin/zsh"
    if [ "$SHELL" != "$_zsh" ]; then
      if ! grep -qF "$_zsh" /etc/shells 2>/dev/null; then
        if /usr/bin/sudo -n sh -c "echo '$_zsh' >> /etc/shells" 2>/dev/null; then
          echo "Added $_zsh to /etc/shells"
        else
          echo "Note: run once to finish zsh setup:"
          echo "  echo '$_zsh' | sudo tee -a /etc/shells && chsh -s '$_zsh'"
        fi
      else
        $DRY_RUN_CMD chsh -s "$_zsh"
      fi
    fi
  '';
}

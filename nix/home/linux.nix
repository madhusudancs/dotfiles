{ config, pkgs, lib, ... }:

let
  # Bitwarden: Electron's SUID sandbox can't be set up in the Nix store on
  # non-NixOS, so we wrap the binary with --no-sandbox and patch the .desktop
  # Exec= to an absolute path (app launchers don't use the shell's PATH).
  bitwarden = pkgs.symlinkJoin {
    name = "bitwarden-desktop";
    paths = [ pkgs.bitwarden-desktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bitwarden --add-flags "--no-sandbox"
      cp --remove-destination \
        "$(readlink -f "$out/share/applications/bitwarden.desktop")" \
        "$out/share/applications/bitwarden.desktop"
      sed -i "s|Exec=bitwarden |Exec=$out/bin/bitwarden |g" \
        "$out/share/applications/bitwarden.desktop"
      sed -i "s|^Icon=bitwarden$|Icon=$out/share/icons/hicolor/512x512/apps/bitwarden.png|" \
        "$out/share/applications/bitwarden.desktop"
    '';
  };

  # Ghostty: nixGL for GPU drivers on non-NixOS. .desktop Exec= lines are
  # absolute store paths so they must be patched to go through the wrapper.
  # Requires: home-manager switch --impure  (nixGL probes system hardware)
  ghostty = pkgs.symlinkJoin {
    name = "ghostty-nixgl";
    paths = [ pkgs.ghostty ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/ghostty
      makeWrapper ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL $out/bin/ghostty \
        --add-flags "${pkgs.ghostty}/bin/ghostty"
      cp --remove-destination \
        "$(readlink -f "$out/share/applications/com.mitchellh.ghostty.desktop")" \
        "$out/share/applications/com.mitchellh.ghostty.desktop"
      sed -i "s|${pkgs.ghostty}/bin/ghostty|$out/bin/ghostty|g" \
        "$out/share/applications/com.mitchellh.ghostty.desktop"
      sed -i "s|^Icon=com.mitchellh.ghostty$|Icon=$out/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.png|" \
        "$out/share/applications/com.mitchellh.ghostty.desktop"
      cp --remove-destination \
        "$(readlink -f "$out/share/dbus-1/services/com.mitchellh.ghostty.service")" \
        "$out/share/dbus-1/services/com.mitchellh.ghostty.service"
      sed -i "s|${pkgs.ghostty}/bin/ghostty|$out/bin/ghostty|g" \
        "$out/share/dbus-1/services/com.mitchellh.ghostty.service"
      sed -i '/^SystemdService=/d' \
        "$out/share/dbus-1/services/com.mitchellh.ghostty.service"
      cp --remove-destination \
        "$(readlink -f "$out/share/systemd/user/app-com.mitchellh.ghostty.service")" \
        "$out/share/systemd/user/app-com.mitchellh.ghostty.service"
      sed -i "s|${pkgs.ghostty}/bin/ghostty|$out/bin/ghostty|g" \
        "$out/share/systemd/user/app-com.mitchellh.ghostty.service"
    '';
  };

  # Zed: nixGL for GPU drivers on non-NixOS. Desktop file uses bare `zeditor`
  # command name so we patch Exec= and TryExec= to the absolute wrapper path.
  # Also provides a `zed` alias (used by EDITOR and jj).
  # Requires: home-manager switch --impure  (nixGL probes system hardware)
  zed = pkgs.symlinkJoin {
    name = "zed-nixgl";
    paths = [ pkgs.zed-editor ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/zeditor
      makeWrapper ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL $out/bin/zeditor \
        --add-flags "${pkgs.zed-editor}/bin/zeditor"
      makeWrapper ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL $out/bin/zed \
        --add-flags "${pkgs.zed-editor}/bin/zeditor"
      cp --remove-destination \
        "$(readlink -f "$out/share/applications/dev.zed.Zed.desktop")" \
        "$out/share/applications/dev.zed.Zed.desktop"
      sed -i "s|Exec=zeditor|Exec=$out/bin/zeditor|g" \
        "$out/share/applications/dev.zed.Zed.desktop"
      sed -i "s|TryExec=zeditor|TryExec=$out/bin/zeditor|g" \
        "$out/share/applications/dev.zed.Zed.desktop"
      sed -i "s|^Icon=zed$|Icon=$out/share/icons/hicolor/512x512/apps/zed.png|" \
        "$out/share/applications/dev.zed.Zed.desktop"
    '';
  };
in
{
  home.username = "madhu";
  home.homeDirectory = "/home/madhu";

  # Register Nix-managed fonts with fontconfig on non-NixOS.
  fonts.fontconfig.enable = true;

  # Make Nix-installed .desktop files visible to GNOME and other XDG-aware apps.
  # home-manager adds ~/.nix-profile/share to the shell PATH, but the systemd
  # user session (which GNOME runs under) needs a separate environment.d entry.
  # NOTE: environment.d is only read when the session starts, so this alone does
  # not help until the next login -- see xdg.dataFile below for the entries that
  # work immediately.
  systemd.user.sessionVariables.XDG_DATA_DIRS =
    "${config.home.homeDirectory}/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share:/var/lib/snapd/desktop";

  programs.git.settings.credential.helper = "gnome-keyring";

  # Bitwarden SSH agent socket (native/Nix installation path)
  programs.zsh.sessionVariables.SSH_AUTH_SOCK =
    "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";

  home.packages = [ bitwarden ghostty zed ];

  # GNOME only searches XDG_DATA_HOME (~/.local/share) plus whatever
  # XDG_DATA_DIRS held when the session started, so ~/.nix-profile/share is
  # invisible to it until the next login. Linking the patched entries into
  # ~/.local/share makes them searchable and launchable right away. Exec= and
  # Icon= are already absolute store paths, so neither PATH nor the icon theme
  # search path needs to include anything from Nix.
  # Bitwarden is deliberately absent here: the Electron app re-registers itself
  # as a protocol handler at runtime and overwrites whatever is at
  # ~/.local/share/applications/bitwarden.desktop, which would make the next
  # switch fail on an unmanaged file. Its self-written entry already has an
  # absolute Exec=, so it works without our help.
  xdg.dataFile = {
    "applications/com.mitchellh.ghostty.desktop".source =
      "${ghostty}/share/applications/com.mitchellh.ghostty.desktop";
    "applications/dev.zed.Zed.desktop".source =
      "${zed}/share/applications/dev.zed.Zed.desktop";

    # Ghostty's entry is DBusActivatable, so the session bus must be able to
    # find its service file on the same terms.
    "dbus-1/services/com.mitchellh.ghostty.service".source =
      "${ghostty}/share/dbus-1/services/com.mitchellh.ghostty.service";
  };

  # Rebuild ~/.local/share/applications/mimeinfo.cache so the MimeType= entries
  # above (zed's text/plain, x-scheme-handler/zed) actually register.
  home.activation.updateDesktopDatabase = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${pkgs.desktop-file-utils}/bin/update-desktop-database \
      "${config.xdg.dataHome}/applications" || true
  '';

  # Reload the session DBus daemon so it picks up new/changed service files
  # in ~/.local/share/dbus-1/services/ after every home-manager switch.
  home.activation.reloadDbus = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
      $DRY_RUN_CMD ${pkgs.dbus}/bin/dbus-send --session \
        --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig || true
    fi
  '';

  # GNOME keyboard shortcut: Ctrl+Alt+T → Ghostty
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Primary><Alt>g";
      command = "${config.home.homeDirectory}/.nix-profile/bin/ghostty";
      name = "Launch Ghostty";
    };
  };

  # ── Login shell ───────────────────────────────────────────────────────────

  home.activation.rebuildFontCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.fontconfig}/bin/fc-cache -fv
  '';

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

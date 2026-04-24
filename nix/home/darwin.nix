{ pkgs, ... }:

{
  home.username = "madhu";
  home.homeDirectory = "/Users/madhu";

  programs.git.settings.credential.helper = "osxkeychain";

  home.packages = [
    pkgs.zed-editor
    # zed-editor installs as `zeditor`; this wrapper provides the `zed` name
    # used throughout configs (EDITOR, jj, etc.)
    (pkgs.writeShellScriptBin "zed" ''exec ${pkgs.zed-editor}/bin/zeditor "$@"'')
  ];
}

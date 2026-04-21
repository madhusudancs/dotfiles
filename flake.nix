{
  description = "Madhu's home configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zig-overlay, nixgl, ... }:
    let
      mkPkgs = system: overlays: import nixpkgs {
        inherit system;
        overlays = overlays;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" "bitwarden-desktop" "google-chrome" ];
      };

      mkHome = system: overlays: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system overlays;
          extraSpecialArgs = { inherit zig-overlay system; };
          modules = [ ./nix/home/default.nix ] ++ extraModules;
        };
    in {
      homeConfigurations = {
        # Linux (x86_64) — most desktops/servers
        "madhu-linux" = mkHome "x86_64-linux" [ nixgl.overlay ] [ ./nix/home/linux.nix ];
        # macOS Apple Silicon
        "madhu-darwin" = mkHome "aarch64-darwin" [] [ ./nix/home/darwin.nix ];
        # macOS Intel
        "madhu-darwin-x86" = mkHome "x86_64-darwin" [] [ ./nix/home/darwin.nix ];
      };
    };
}

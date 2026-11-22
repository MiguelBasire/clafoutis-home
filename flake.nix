{
  description = "Home Manager configuration for miguel (macOS and Linux)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Makes nix-installed .app bundles show up in Spotlight/Launchpad by
    # generating real trampoline apps in ~/Applications, since /nix is a
    # nobrowse volume Spotlight won't index directly. macOS only.
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, mac-app-util, ... }:
    let
      # One shared home.nix; per-platform differences live inside it,
      # behind pkgs.stdenv.hostPlatform.isDarwin / isLinux.
      mkHome = system: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = extraModules ++ [ ./home.nix ];
        };
    in {
      homeConfigurations."miguel" = mkHome "aarch64-darwin" [
        mac-app-util.homeManagerModules.default
      ];
      homeConfigurations."miguel-linux" = mkHome "x86_64-linux" [ ];
    };
}

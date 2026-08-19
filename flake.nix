{
  description = "Home Manager configuration for miguel (Neovim/LazyVim)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Makes nix-installed .app bundles show up in Spotlight/Launchpad by
    # generating real trampoline apps in ~/Applications, since /nix is a
    # nobrowse volume Spotlight won't index directly.
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, mac-app-util, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."miguel" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          mac-app-util.homeManagerModules.default
          ./home.nix
        ];
      };
    };
}

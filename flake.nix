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
      pkgs = import nixpkgs {
        inherit system;
        # acli (Atlassian's official CLI, used for Bitbucket Cloud) ships
        # under an unfree license. Scoped to just that package rather than
        # a blanket allowUnfree, so anything else unfree still fails loudly.
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "acli"
        ];
      };
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

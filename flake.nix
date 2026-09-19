{
  description = "Home Manager configuration for miguel (macOS + Linux)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Makes nix-installed .app bundles show up in Spotlight/Launchpad by
    # generating real trampoline apps in ~/Applications, since /nix is a
    # nobrowse volume Spotlight won't index directly. Darwin-only: it builds
    # its trampolines with osacompile, so it is imported by the macOS
    # configuration only, never by the Linux one.
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, mac-app-util, ... }:
    let
      # acli (Atlassian's official CLI, used for Bitbucket Cloud) ships under
      # an unfree license. Scoped to just that package rather than a blanket
      # allowUnfree, so anything else unfree still fails loudly.
      #
      # Two names, because nixpkgs packages it differently per platform: on
      # Darwin the unfree derivation is `acli` itself, but on Linux `acli` is
      # a buildFHSEnv wrapper around `acli-unwrapped`, and it is the *inner*
      # derivation that carries the license. Listing only "acli" evaluates
      # fine on Darwin and fails on Linux with:
      #   error: Refusing to evaluate package 'acli-unwrapped-...' because it
      #   has an unfree license
      unfreeAllowed = [ "acli" "acli-unwrapped" ];

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg: builtins.elem (nixpkgs.lib.getName pkg) unfreeAllowed;
      };

      mkHome = { system, modules }: home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs system;
        inherit modules;
      };

      mac = mkHome {
        system = "aarch64-darwin";
        modules = [
          mac-app-util.homeManagerModules.default
          ./common.nix
          ./darwin.nix
        ];
      };
    in {
      homeConfigurations = {
        "miguel@mac" = mac;
        # Kept as an alias so the pre-split command line
        # (`.#homeConfigurations.miguel.activationPackage`) still resolves.
        "miguel" = mac;

        "miguel@clafoutis02" = mkHome {
          system = "x86_64-linux";
          modules = [
            ./common.nix
            ./linux.nix
          ];
        };

        # Throwaway no-sudo user on the same laptop, for bringing up a plain
        # sway desktop (sway.nix) without Regolith before miguel switches.
        # Same modules as miguel@clafoutis02 plus sway.nix; only the identity
        # differs. See "Testing a Regolith-free desktop" in README.md.
        "hmtest@clafoutis02" = mkHome {
          system = "x86_64-linux";
          modules = [
            ./common.nix
            ./linux.nix
            ./sway.nix
            ({ lib, ... }: {
              home.username = lib.mkForce "hmtest";
              home.homeDirectory = lib.mkForce "/home/hmtest";
            })
          ];
        };
      };
    };
}

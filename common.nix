# Everything that is genuinely the same on both machines.
#
# Anything that differs — home directory, fonts, theming, the Nix shell
# bootstrap, per-host Neovim plugins — lives in darwin.nix / linux.nix.
{ config, lib, pkgs, ... }:

{
  home.username = "miguel";
  # Do not bump this after the first switch; it just pins default option
  # behavior to the Home Manager release it was written against.
  home.stateVersion = "24.11";

  # Neovim itself, plus everything LazyVim wants at runtime:
  # ripgrep/fd for telescope/fzf-lua, lazygit for the git UI, a nerd font
  # for icons, and node/python/unzip/make for mason.nvim installers.
  # A C compiler comes from Xcode Command Line Tools on macOS and from the
  # distro toolchain on Linux, so it's intentionally not listed here.
  # fzf itself is installed via programs.fzf below (not listed here) so its
  # module can also own the package version.
  #
  # Note: on Linux a font in home.packages is only visible to applications
  # once fontconfig knows about it — see fonts.fontconfig.enable in linux.nix.
  home.packages = with pkgs; [
    neovim
    git
    ripgrep
    fd
    lazygit
    bat
    btop
    tree-sitter
    nodejs_22
    python3
    unzip
    gnumake
    nerd-fonts.fira-code
    gh
    # Atlassian's official CLI — covers Bitbucket Cloud (bitbucket.org).
    # nixpkgs also has a `bitbucket-cli` package, but that one only talks to
    # self-hosted Bitbucket Server/Data Center's REST API, not bitbucket.org.
    acli
  ];

  # The LazyVim starter config lives in ./nvim (git-tracked here).
  # recursive = true makes ~/.config/nvim a real directory of per-file
  # symlinks rather than one symlink to the store, so lazy.nvim can still
  # write lazy-lock.json / plugin state next to it at runtime.
  #
  # Per-host plugin specs are layered on top as individual home.file entries
  # in darwin.nix / linux.nix; lazy.nvim merges everything it finds under
  # lua/plugins/, so extra files just work.
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # Was a per-shell `export` in the hand-written ~/.zshrc before zsh was
    # brought under Home Manager; moved here so it applies universally
    # (any HM-managed shell), not just zsh. Load-bearing on the Mac: without
    # it, the `nix` CLI itself refuses flake/`nix build`-style commands,
    # since /etc/nix/nix.conf doesn't enable these features globally there.
    # Redundant but harmless on clafoutis02, which already has the same
    # setting in ~/.config/nix/nix.conf.
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
  };

  # Was `export PATH="$HOME/.local/bin:$PATH"` in the hand-written ~/.zshrc.
  # Load-bearing on clafoutis02: ~/.config/sway/install.sh deploys
  # rescan-displays / dock-diag / screenshot there.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # Font, size and theme are per-host — see darwin.nix / linux.nix.
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    settings = {
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
  };

  # zsh is Home Manager's now (below), so every one of these gets its
  # normal, first-class enableZshIntegration instead of a hand-appended
  # ~/.zshrc line.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Starship's official "Gruvbox Rainbow" preset, fetched verbatim and
  # parsed rather than hand-transcribed, so the glyphs/colors stay
  # byte-accurate to the upstream preset
  # (https://starship.rs/presets/#gruvbox-rainbow).
  #
  # clafoutis02 keeps the preset's structure but overrides the palette to
  # match its Nord terminal theme — see linux.nix.
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (
      builtins.readFile (
        pkgs.fetchurl {
          url = "https://starship.rs/presets/toml/gruvbox-rainbow.toml";
          sha256 = "sha256-YFTZi5FggispDhtp85dUTb26C7Sfv+Cx8MVnUy4XANk=";
        }
      )
    );
  };

  # fzf's own Ctrl+R (history search) and Ctrl+T / **<Tab> (fuzzy file
  # insertion) keybindings — previously unavailable since they're also
  # gated behind zsh integration.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # Ghost-text history suggestions.
    autosuggestion.enable = true;
    shellAliases = {
      gs = "git status";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gcm = "git commit -m";
      gca = "git commit --amend";
      gco = "git checkout";
      gcb = "git checkout -b";
      gb = "git branch";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git push";
      gpl = "git pull";
      gl = "git log --oneline --graph --decorate";
      gla = "git log --oneline --graph --decorate --all";
      gst = "git stash";
      gstp = "git stash pop";
      grb = "git rebase";
      grbi = "git rebase -i";
    };
    # Fuzzy Tab-completion menu. Home Manager sources plugins (mkOrder 900)
    # after enableCompletion's compinit (570) and autosuggestion (700), so
    # the ordering fzf-tab needs is automatic here — no more hand-managed
    # fixed-path symlink workaround.
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];
    # The Nix shell bootstrap is per-host: the multi-user installer lays its
    # profile scripts down in different places on macOS and Linux. See the
    # initContent blocks in darwin.nix / linux.nix.
  };

  programs.home-manager.enable = true;
}

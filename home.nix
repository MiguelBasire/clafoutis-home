{ config, lib, pkgs, ... }:

{
  home.username = "miguel";
  home.homeDirectory = "/Users/miguel";
  # Do not bump this after the first switch; it just pins default option
  # behavior to the Home Manager release it was written against.
  home.stateVersion = "24.11";

  # Neovim itself, plus everything LazyVim wants at runtime:
  # ripgrep/fd for telescope/fzf-lua, lazygit for the git UI, a nerd font
  # for icons, and node/python/unzip/make for mason.nvim installers.
  # A C compiler for treesitter parsers comes from Xcode Command Line
  # Tools (already installed), so it's intentionally not listed here.
  # fzf itself is installed via programs.fzf below (not listed here) so its
  # module can also own the package version.
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
  ];

  # The LazyVim starter config lives in ./nvim (git-tracked here).
  # recursive = true makes ~/.config/nvim a real directory of per-file
  # symlinks rather than one symlink to the store, so lazy.nvim can still
  # write lazy-lock.json / plugin state next to it at runtime.
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # Was a per-shell `export` in the hand-written ~/.zshrc before zsh was
    # brought under Home Manager; moved here so it applies universally
    # (any HM-managed shell), not just zsh. Load-bearing: without it, the
    # `nix` CLI itself refuses flake/`nix build`-style commands, since
    # /etc/nix/nix.conf doesn't enable these features globally on this
    # machine.
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
  };

  # Was `export PATH="$HOME/.local/bin:$PATH"` in the hand-written ~/.zshrc.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    # Matches Neovim's gruvbox colorscheme and Starship's Gruvbox Rainbow
    # preset so terminal, editor, and prompt all share one palette.
    themeFile = "gruvbox-dark";
    settings = {
      # The plain "FiraCode Nerd Font" family fails to resolve in this
      # Kitty build even though macOS/CoreText itself sees it fine
      # (confirmed directly via CTFontManagerCopyAvailableFontFamilyNames) —
      # Kitty falls back to Menlo and Nerd Font icons render as tofu boxes.
      # The "Mono" variant resolves correctly, and is the technically
      # correct choice for a terminal anyway: guaranteed fixed-width glyphs
      # for icons, vs. the plain family's proportional metrics.
      font_family = "FiraCode Nerd Font Mono";
      font_size = 14.0;
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

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Starship's official "Gruvbox Rainbow" preset, fetched verbatim and
    # parsed rather than hand-transcribed, so the glyphs/colors stay
    # byte-accurate to the upstream preset
    # (https://starship.rs/presets/#gruvbox-rainbow).
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
    # Preserves the Nix multi-user installer's shell bootstrap (profile
    # sourcing, daemon env) exactly as it was in the hand-written
    # ~/.zshrc before this migration — Home Manager emits it now instead
    # of it being manually maintained. mkOrder 500 keeps it early,
    # mirroring its original position at the top of the file.
    initContent = lib.mkOrder 500 ''
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi

      if [ -e "$HOME/.nix-profile/etc/profile.d/nix-daemon.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix-daemon.sh"
      fi

      if [ -e "$HOME/.nix-defexpr/profile" ] && [ -z "''${NIX_PATH+x}" ]; then
        export NIX_PATH="$HOME/.nix-defexpr/channels"
      fi
    '';
  };

  programs.home-manager.enable = true;
}

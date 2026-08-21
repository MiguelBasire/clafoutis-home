{ pkgs, ... }:

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
  home.packages = with pkgs; [
    neovim
    git
    ripgrep
    fd
    fzf
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
  };

  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    # Matches Neovim's gruvbox colorscheme and Starship's Gruvbox Rainbow
    # preset so terminal, editor, and prompt all share one palette.
    themeFile = "gruvbox-dark";
    settings = {
      font_family = "FiraCode Nerd Font";
      font_size = 14.0;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
  };

  # zsh itself isn't managed by Home Manager here, so shell integration for
  # these is wired up by hand with lines appended to ~/.zshrc rather than
  # via enableZshIntegration (which only works when programs.zsh.enable =
  # true).
  programs.zoxide.enable = true;

  # zsh-autosuggestions (ghost-text history suggestions) and fzf-tab (fuzzy
  # Tab-completion menu). Symlinked to a fixed path rather than sourced
  # straight from the Nix store, so the `source` line appended to ~/.zshrc
  # never has to change when the store path's hash changes on update.
  home.file.".local/share/zsh-plugins/zsh-autosuggestions.zsh".source =
    "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
  home.file.".local/share/zsh-plugins/fzf-tab.plugin.zsh".source =
    "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh";

  programs.starship = {
    enable = true;
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

  programs.home-manager.enable = true;
}

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
    settings = {
      font_family = "FiraCode Nerd Font";
      font_size = 14.0;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
  };

  # zsh itself isn't managed by Home Manager here, so shell integration is
  # wired up by hand with a line appended to ~/.zshrc rather than via
  # enableZshIntegration (which only works when programs.zsh.enable = true).
  programs.zoxide.enable = true;

  programs.home-manager.enable = true;
}

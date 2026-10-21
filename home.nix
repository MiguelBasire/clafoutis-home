{ config, lib, pkgs, ... }:

let
  # Bitbucket Cloud CLI ("gh for Bitbucket"). Not in nixpkgs, so packaged
  # directly from source, pinned to a commit. Replaced acli (Atlassian's
  # own official CLI) here after discovering acli has no Bitbucket
  # subcommand at all (Jira/Confluence/Guard/admin/rovodev only) --
  # checked via `acli --help`, not just its homepage, this time.
  bbt = pkgs.buildGoModule {
    pname = "bbt";
    version = "0-unstable-2025-12-18";
    src = pkgs.fetchgit {
      url = "https://codeberg.org/romaintb/bbt.git";
      rev = "07597ca2806eb0b1540b2dd8278c7c85dc794ccf";
      hash = "sha256-Ds2liO5Ju7dDpgiWLk8G3clkDV6LbhunhjDvm7NAYCQ=";
    };
    vendorHash = "sha256-6eG5ru0cnoy7Oh5GtrHbBAt2D5MAe+OgJVZlBrY6/l4=";
    meta = {
      description = "Bitbucket Cloud CLI (\"gh for Bitbucket\")";
      homepage = "https://codeberg.org/romaintb/bbt";
      license = lib.licenses.mit;
      mainProgram = "bbt";
    };
  };

  # "Mercio" in Spotlight/Launchpad: opens a new kitty instance on the Mercio
  # workspace session (the same file Cmd+Shift+M opens from inside kitty).
  # mac-app-util turns it into a trampoline like kitty's, since /nix is nobrowse.
  mercioWorkspace = let
    kittyApp = "${config.programs.kitty.package}/Applications/kitty.app";
  in pkgs.runCommand "mercio-workspace" { } ''
    contents=$out/Applications/Mercio.app/Contents
    mkdir -p $contents/MacOS $contents/Resources
    cp ${kittyApp}/Contents/Resources/kitty.icns $contents/Resources/mercio.icns
    cat > $contents/Info.plist <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>Mercio</string>
      <key>CFBundleIdentifier</key><string>com.miguel.mercio-workspace</string>
      <key>CFBundleExecutable</key><string>mercio</string>
      <key>CFBundleIconFile</key><string>mercio</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>LSUIElement</key><true/>
    </dict>
    </plist>
    EOF
    cat > $contents/MacOS/mercio <<'EOF'
    #!/bin/sh
    exec /usr/bin/open -n -a "${kittyApp}" --args --session "$HOME/.config/kitty/sessions/mercio.kitty-session"
    EOF
    chmod +x $contents/MacOS/mercio
  '';
in
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
    gh
    bbt
    mercioWorkspace
    # macOS's system Ruby (/usr/bin/ruby) is 2.6.10, EOL since March 2022 --
    # too old for current fastlane (>=2.235 needs Ruby >=3.0; even
    # >=2.232 needs >=2.7), which the qalyo-ios repo's Gemfile.lock pins
    # to. A modern Ruby earlier on PATH than /usr/bin lets `bundle`
    # resolve/run newer gem versions there instead of capping out on
    # whatever the ancient system Ruby can still support.
    ruby
    # Tooling for LazyVim's lang.nix / lang.ruby extras (nvim/lua/plugins/extras.lua).
    # These come from Nix, not Mason (see `mason = false` there): Mason
    # can't install nil at all here, and builds ruby-lsp/rubocop's native
    # gems against whatever /nix/store Ruby is on PATH at install time, so
    # they stop loading ("linked to incompatible libruby") after every Ruby bump.
    nil
    nixfmt
    statix
    ruby-lsp
    rubocop
  ];

  # The LazyVim starter config lives in ./nvim (git-tracked here).
  # recursive = true makes ~/.config/nvim a real directory of per-file
  # symlinks rather than one symlink to the store, so lazy.nvim can still
  # write lazy-lock.json / plugin state next to it at runtime.
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # QWERTY-fr: a QWERTY-based keyboard layout with French accents
  # (https://github.com/qwerty-fr/qwerty-fr), pinned to a specific commit.
  #
  # Deliberately NOT a home.file entry: home.file symlinks each leaf file
  # into /nix/store, and System Settings' Input Sources picker never
  # showed the layout even after a logout -- the same class of problem
  # mac-app-util works around for GUI .app bundles, where content that
  # only exists as a symlink into the nobrowse /nix volume is invisible
  # to some macOS system-integration surfaces even though it's perfectly
  # readable by a normal process (Kitty/nvim's configs are fine because
  # *we* read those, not a sandboxed system picker). Fix: copy real files
  # into place on every activation instead of symlinking.
  #
  # Installing the bundle only gets the file in place; macOS still needs
  # a one-time manual step to activate it: System Settings > Keyboard >
  # Input Sources > + > Others > qwerty-fr (may need a logout to appear).
  # That activation step lives in ~/Library/Preferences/com.apple.HIToolbox.plist,
  # which isn't something Home Manager manages here.
  home.activation.installQwertyFrLayout = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    layoutSrc="${
      pkgs.fetchFromGitHub {
        owner = "qwerty-fr";
        repo = "qwerty-fr";
        rev = "812e3c14e8366bb211688fe0c494f34a8e39885d";
        hash = "sha256-iXme/Edv2eG8WP58GXbFzUfVqr26Lu7lgJzGq21iE2E=";
      }
    }/mac/bundle/qwerty-fr.bundle"
    layoutDest="$HOME/Library/Keyboard Layouts/qwerty-fr.bundle"
    $DRY_RUN_CMD mkdir -p "$HOME/Library/Keyboard Layouts"
    if [ -e "$layoutDest" ]; then
      # /nix/store paths are read-only, and cp -RL preserves that mode on
      # the copy -- without this chmod, even the owner can't rm/replace
      # it on the next activation.
      $DRY_RUN_CMD chmod -R u+w "$layoutDest"
      $DRY_RUN_CMD rm -rf "$layoutDest"
    fi
    $DRY_RUN_CMD cp -RL "$layoutSrc" "$layoutDest"
    $DRY_RUN_CMD chmod -R u+w "$layoutDest"
  '';

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
    keybindings = {
      # Opens the Mercio workspace, or switches to it when it is already open.
      # The path is relative to ~/.config/kitty; the session file comes from
      # ./kitty/sessions below, and its windows run inside the Mercio repo's
      # nix dev shell.
      "cmd+shift+m" = "goto_session sessions/mercio.kitty-session";
    };
  };

  # Mercio workspace session, opened by cmd+shift+m and the Mercio launcher.
  # mercio-pane wraps every window's command in the repo's nix dev shell.
  home.file.".config/kitty/sessions/mercio.kitty-session".source =
    ./kitty/sessions/mercio.kitty-session;
  home.file.".config/kitty/sessions/mercio-pane" = {
    source = ./kitty/sessions/mercio-pane;
    executable = true;
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

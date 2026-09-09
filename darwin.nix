# macOS-only slice (aarch64-darwin).
#
# Imported alongside common.nix and mac-app-util's Home Manager module.
{ config, lib, pkgs, ... }:

{
  home.homeDirectory = "/Users/miguel";

  # QWERTY-fr: a QWERTY-based keyboard layout with French accents
  # (https://github.com/qwerty-fr/qwerty-fr), pinned to a specific commit.
  #
  # macOS-only. clafoutis02 gets the same layout by a completely different
  # route: an XKB symbols file at ~/.config/xkb/symbols/us_qwerty-fr,
  # deployed by ~/.config/sway/install.sh and bound per input device in
  # ~/.config/regolith3/sway/config.d/95-keyboard-layout. Nothing here
  # applies there.
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

  # Matches Neovim's gruvbox colorscheme and Starship's Gruvbox Rainbow
  # preset so terminal, editor, and prompt all share one palette.
  programs.kitty = {
    themeFile = "gruvbox-dark";
    settings = {
      # The plain "FiraCode Nerd Font" family fails to resolve in this
      # Kitty build even though macOS/CoreText itself sees it fine
      # (confirmed directly via CTFontManagerCopyAvailableFontFamilyNames) —
      # Kitty falls back to Menlo and Nerd Font icons render as tofu boxes.
      # The "Mono" variant resolves correctly, and is the technically
      # correct choice for a terminal anyway: guaranteed fixed-width glyphs
      # for icons, vs. the plain family's proportional metrics.
      #
      # This is a CoreText problem specifically; under fontconfig on Linux
      # the plain family resolves fine, so the workaround does not need to
      # be mirrored in linux.nix.
      font_family = "FiraCode Nerd Font Mono";
      font_size = 14.0;
    };
  };

  # Gruvbox to match Kitty and Starship. Kept out of the shared nvim/ tree
  # because clafoutis02 has no colorscheme override at all and runs
  # LazyVim's default — see linux.nix.
  home.file.".config/nvim/lua/plugins/colorscheme.lua".source =
    ./nvim-darwin/lua/plugins/colorscheme.lua;

  # Preserves the Nix multi-user installer's shell bootstrap (profile
  # sourcing, daemon env) exactly as it was in the hand-written
  # ~/.zshrc before this migration — Home Manager emits it now instead
  # of it being manually maintained. mkOrder 500 keeps it early,
  # mirroring its original position at the top of the file.
  #
  # These are the macOS installer's paths; the Linux daemon install puts
  # the equivalent script somewhere else entirely (see linux.nix).
  programs.zsh.initContent = lib.mkOrder 500 ''
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
}

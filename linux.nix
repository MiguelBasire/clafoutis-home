# Linux-only slice (x86_64-linux) — the "clafoutis02" TUXEDO laptop running
# Regolith/sway on Wayland.
#
# Scope boundary worth keeping in mind: this file owns the CLI / editor /
# terminal layer only. The window-manager layer (XKB symbol files, Regolith
# sway config.d partials, ~/.local/bin helper scripts) stays with
# ~/.config/sway/install.sh, which deploys it imperatively. Do not let Home
# Manager start managing sway here: Regolith runs `sway -c
# /etc/regolith/sway/config` and never reads ~/.config/sway/config, so a
# programs.sway block would generate a file nothing loads.
{ config, lib, pkgs, ... }:

{
  home.homeDirectory = "/home/miguel";

  # Required for fonts installed via home.packages (nerd-fonts.fira-code in
  # common.nix) to be discoverable at all. macOS links them into
  # ~/Library/Fonts automatically; on Linux they stay invisible to every
  # application until fontconfig is told about them. Without this, Kitty
  # silently falls back and every Nerd Font glyph renders as tofu.
  #
  # This generates ~/.config/fontconfig/conf.d/10-hm-fonts.conf and
  # 52-hm-default-fonts.conf; the latter sets default sans/serif/mono
  # families, so expect a small change in system font rendering.
  fonts.fontconfig.enable = true;

  # Nord, to match the rest of this machine's theming — deliberately not
  # the Mac's Gruvbox. "Nord" is the stock kitty-themes entry and is
  # byte-identical to the ~/.config/kitty/current-theme.conf this machine
  # was using via a hand-written `include`, so appearance is unchanged and
  # current-theme.conf becomes redundant.
  programs.kitty = {
    themeFile = "Nord";
    settings = {
      # Monoid, not the Mac's Fira Code — this is what the machine already
      # uses. nerd-fonts.fira-code is still installed (common.nix) and is
      # now fontconfig-visible, so switching is a one-line change.
      font_family = "Monoid Nerd Font";
      font_size = 10.0;
      background_opacity = "0.7";
      # Used by ~/.config/sway/bin/* and for `kitten @` scripting.
      allow_remote_control = "yes";
      disable_ligatures = "never";
      scrollback_pager_history_size = 200;
    };
  };

  # Same Gruvbox Rainbow preset as the Mac (common.nix), but with the
  # palette retuned to the slate/blue of this machine's Nord terminal
  # theme. These are the values that were already in the hand-written
  # ~/.config/starship.toml; keeping them here means the preset itself can
  # keep tracking upstream without losing the customisation.
  programs.starship.settings.palettes.gruvbox_dark = lib.mkForce {
    color_fg0 = "#ffffff";
    color_bg1 = "#3d5470";
    color_bg3 = "#4a6287";
    color_blue = "#6d8f8e";
    color_aqua = "#638d99";
    color_green = "#98971a";
    color_orange = "#3d5470";
    color_purple = "#b16286";
    color_red = "#cc241d";
    color_yellow = "#556a80";
  };

  # Host-only Neovim plugin specs, layered on top of the shared nvim/ tree.
  # Kept out of nvim/ so adopting this config on the Mac doesn't silently
  # pull in Scala/Kotlin tooling that isn't wanted there; promote any of
  # them into nvim/ if that changes.
  #
  # Note there is deliberately no colorscheme.lua here: this machine runs
  # LazyVim's default rather than the Mac's gruvbox override.
  home.file = {
    # Replaces the LSP that lazyvim.plugins.extras.lang.kotlin sets up.
    # Linux-specific by construction — it resolves an intellij-server
    # binary installed by hand under ~/.local/share/kotlin-lsp.
    ".config/nvim/lua/plugins/kotlin.lua".source =
      ./nvim-linux/lua/plugins/kotlin.lua;
    ".config/nvim/lua/plugins/nvim-metals.lua".source =
      ./nvim-linux/lua/plugins/nvim-metals.lua;
    ".config/nvim/lua/plugins/training.lua".source =
      ./nvim-linux/lua/plugins/training.lua;
  };

  # Linux counterpart of the Mac's bootstrap block. The multi-user installer
  # puts its profile script under /nix/var/nix/profiles/default here, not in
  # ~/.nix-profile, and the system-wide /etc/profile.d/nix.sh only fires for
  # login shells — so a plain interactive zsh can otherwise come up without
  # nix on PATH. Guarded, so it is a no-op if the layout ever changes.
  programs.zsh.initContent = lib.mkOrder 500 ''
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  '';
}

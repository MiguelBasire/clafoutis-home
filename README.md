# Home Manager config

Standalone [Home Manager](https://nix-community.github.io/home-manager/) setup
for this Mac — no `nix-darwin`, just a flake that manages a chunk of the user
environment declaratively. Started as "configure Neovim with LazyVim through
Nix" and grew from there.

## Layout

```
flake.nix   -- inputs (nixpkgs, home-manager, mac-app-util) and the
               homeConfigurations."miguel" output
home.nix    -- everything that's actually managed: packages, Neovim config
               wiring, Kitty, zoxide
nvim/       -- the LazyVim starter template, git-tracked here, symlinked
               file-by-file into ~/.config/nvim
```

## Applying changes

```sh
cd ~/.config/home-manager
nix build .#homeConfigurations.miguel.activationPackage -L
./result/activate
```

(Equivalent to `home-manager switch --flake .#miguel`, just via the flake's
own build output so it doesn't depend on the `home-manager` CLI already being
on `PATH`.) Commit `flake.lock` changes along with the rest — that's what
pins exact package versions.

## What's managed and why

- **Neovim + LazyVim.** `home.packages` installs `neovim` itself plus
  everything LazyVim wants at runtime: `ripgrep`/`fd` (telescope/fzf-lua),
  `lazygit`, `tree-sitter` (CLI), `nodejs`/`python3`/`unzip`/`gnumake` (for
  Mason-installed LSPs/formatters/linters), and a Fira Code Nerd Font for
  icons (`fzf` moved to `programs.fzf` — see below). A C compiler comes
  from Xcode Command Line Tools, already on the system — deliberately not
  duplicated via `pkgs.gcc`.

  The LazyVim config itself is **not** a Home Manager module — LazyVim
  manages its own plugins via `lazy.nvim`, which is orthogonal to Nix. What
  Nix does is vendor the starter config (`nvim/`) into `~/.config/nvim` with
  `home.file` using `recursive = true`. That makes `~/.config/nvim` a real
  directory containing individual symlinks per file, rather than one symlink
  to the Nix store — important because `lazy.nvim` needs to *write*
  `lazy-lock.json` next to the config, and the Nix store is read-only. A
  plain non-recursive symlink of the whole directory would break that.

- **`bat`, `btop`, `fd`, `fzf`, `lazygit`, `ripgrep`, `neovim`.** Originally
  installed imperatively via `nix profile install`. Migrated into this
  config and removed from the imperative profile (`nix profile remove`) so
  there's one source of truth instead of two overlapping ones.

- **Kitty** (`programs.kitty`). Config is generated to
  `~/.config/kitty/kitty.conf` from the `settings` block in `home.nix` — edit
  it there, not the generated file directly, or changes get overwritten on
  the next switch. Font is pinned to the same Nerd Font Neovim uses. Zsh
  shell integration (jump-to-prompt, cursor shape, cwd tracking) is turned
  on via `shellIntegration.enableZshIntegration`.

  `font_family` must be set to the **`Mono`** variant of a Nerd Font (e.g.
  `"FiraCode Nerd Font Mono"`), not the plain family name. This Kitty build
  fails to resolve the plain `"FiraCode Nerd Font"` family and silently
  falls back to Menlo (breaking every icon glyph), even though macOS itself
  has it correctly registered — confirmed by querying
  `CTFontManagerCopyAvailableFontFamilyNames` directly via a Swift one-liner,
  bypassing Kitty entirely. A `fontd` restart and a full logout/reboot both
  failed to fix it; switching to the `Mono` variant is what actually worked
  (and is the more correct choice for a terminal regardless, since it
  guarantees fixed-width glyphs instead of the plain family's proportional
  metrics).

- **`mac-app-util`** (flake input + Home Manager module). Fixes a
  Nix-on-macOS-specific problem: `/nix` is mounted as its own APFS volume
  with the `nobrowse` flag, so Spotlight's indexer skips everything under it
  — including GUI `.app` bundles Nix installs, even when symlinked into
  `~/Applications`. `mac-app-util` generates real "trampoline" app bundles
  in `~/Applications/Home Manager Trampolines/` on every switch — small real
  files that just launch the actual Nix-store binary, but live somewhere
  Spotlight *will* index. Also keeps Dock pins pointed at the right binary
  across updates. Applies automatically to any GUI app added via
  `home.packages` — Kitty is the only one so far.

- **`zsh`** (`programs.zsh`) — see the dedicated section below; this is what
  everything else's `enableZshIntegration` now plugs into.

- **`zoxide`**, **`starship`**, **`fzf`** — all `enable = true` with
  `enableZshIntegration = true`, now that `zsh` is Home Manager's. No more
  hand-appended `eval "$(... init zsh)"` lines.

## `~/.zshrc` is Home Manager's

As of the "Bring `.zshrc` under Home Manager" commit (see History),
`programs.zsh.enable = true;` and `.zshrc` (plus
`.zshenv`/`.zprofile`) are generated files — symlinks into `/nix/store`, same
as `kitty.conf` and `~/.config/nvim`. **Don't hand-edit `.zshrc` anymore** —
it gets silently overwritten on the next `./result/activate`. Everything
that used to be a manual line lives in `home.nix` now:

| What | Where in `home.nix` |
|---|---|
| Nix multi-user installer's shell bootstrap (`nix.sh`, `nix-daemon.sh`, `NIX_PATH` fallback) | `programs.zsh.initContent` at `lib.mkOrder 500`, preserved verbatim from the original hand-written block |
| `PATH="$HOME/.local/bin:$PATH"` | `home.sessionPath` |
| `NIX_CONFIG="extra-experimental-features = nix-command flakes"` | `home.sessionVariables` (moved here from a zsh-only export — now applies to *any* HM-managed shell, and is load-bearing: without it `nix build`/`nix flake` refuse to run, since `/etc/nix/nix.conf` doesn't enable those features globally on this machine) |
| `autoload -Uz compinit; compinit` | `programs.zsh.enableCompletion = true;` |
| `source .../zsh-autosuggestions.zsh` | `programs.zsh.autosuggestion.enable = true;` — no plugin wiring needed, it's a first-class option |
| `source .../fzf-tab.plugin.zsh` (previously via a fixed-path symlink in `~/.local/share/zsh-plugins/`, worked around the Nix store's volatile hash) | `programs.zsh.plugins = [{ name = "fzf-tab"; src = pkgs.zsh-fzf-tab; file = "share/fzf-tab/fzf-tab.plugin.zsh"; }];` — Home Manager sources plugins at `mkOrder 900`, safely after `enableCompletion`'s compinit (570) and autosuggestion (700), so the ordering `fzf-tab` needs is automatic |
| `eval "$(zoxide init zsh)"` / `eval "$(starship init zsh)"` | `enableZshIntegration = true;` on `programs.zoxide` / `programs.starship` respectively |

**Two things that started working as a side effect, not because anyone asked for them:**
- `programs.kitty.shellIntegration.enableZshIntegration` was already `true`
  before this migration, but was silently inert — Kitty's integration script
  only activates by being sourced from `.zshrc`, and Home Manager didn't own
  that file yet. It's real now: Kitty's `OSC 133` prompt markers fire (visible
  via `kitten @ get-text --ansi`), enabling cursor-shape-per-vi-mode, jump to
  previous prompt, and cwd-aware new tabs/splits.
- `programs.fzf.enableZshIntegration` adds fzf's own `Ctrl+R` (history
  search) and `Ctrl+T` / `**<Tab>` (fuzzy file insertion) — the `fzf` binary
  was installed before, but its keybindings were never wired up.
- Shell history now actually persists across sessions
  (`HISTFILE=~/.zsh_history`, `HISTSIZE`/`SAVEHIST=10000`, `SHARE_HISTORY`)
  — `enableCompletion`'s defaults. The old hand-written `.zshrc` never set
  any of this, so history likely wasn't being saved between sessions before.

**Migration mechanics, for the record:** the first `./result/activate` after
adding `programs.zsh.enable = true;` refused with *"Existing file
'/Users/miguel/.zshrc' would be clobbered"* — expected, since the old file
wasn't Home-Manager-owned. Fix was `cp ~/.zshrc ~/.zshrc.pre-homemanager-backup`
(manual safety copy, still on disk), then `rm ~/.zshrc` and re-running
`activate`. The raw `nix build` + `./result/activate` path doesn't take a
`-b backup` flag the way the `home-manager switch` CLI does — hence the
manual `cp`/`rm` instead.

## History

- `4b31166` — initial config: Neovim/LazyVim via Nix, migrated
  `bat`/`btop`/`fd`/`fzf`/`lazygit`/`neovim`/`ripgrep` off the imperative
  `nix profile`.
- `462528a` — added Kitty, wired to the shared Nerd Font.
- `03b7917` — added `mac-app-util` (Spotlight/Launchpad fix for Kitty).
- `9765362` — added `zoxide`.
- `581668d` — switched the Nerd Font from JetBrains Mono to Fira Code.
- `35405cc` → `9c579de` → `d82c801` → `5e22fd6` — theme churn: Gruvbox Dark
  on Kitty, then matched to Tokyo Night Moon (Neovim's default), then
  Starship added with the Tokyo Night preset, then everything (Kitty,
  Neovim, Starship) settled on Gruvbox together.
- `fd73ef2` — added `zsh-autosuggestions` + `fzf-tab` (fixed-path symlink
  workaround, since zsh wasn't Home-Manager-owned yet at this point).
- `efc6648` / `daadf1f` — fixed + documented the Kitty Nerd Font `Mono`
  variant gotcha.
- `f7b83f1` — brought `.zshrc` under Home Manager; see the dedicated
  section above for the full mapping and migration mechanics.

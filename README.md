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
  Mason-installed LSPs/formatters/linters), and a JetBrains Mono Nerd Font
  for icons. A C compiler comes from Xcode Command Line Tools, already on
  the system — deliberately not duplicated via `pkgs.gcc`.

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
  shell integration (jump-to-prompt, cursor shape) is turned on via
  `shellIntegration.enableZshIntegration` — this one *is* safe to set
  without Home Manager owning `.zshrc`, because Kitty's own integration works
  by having the `kitty` binary inject a snippet at shell-launch time, not by
  Home Manager writing into your `.zshrc`.

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

- **`zoxide`** (`programs.zoxide.enable = true`). Just installs the binary;
  see below for why the shell integration isn't done the "normal" way.

## `.zshrc`: hand-maintained, on purpose (for now)

`~/.zshrc` is **not** managed by Home Manager. `programs.zsh.enable` is left
off. This was a deliberate choice to keep the blast radius small while
bringing Neovim/Kitty/etc. under Nix — not a technical limitation. Notes to
self (or future-me re-reading this) in case that decision gets revisited:

**Why `zoxide`'s shell hook is a manual line instead of
`enableZshIntegration`.** Home Manager's `programs.zoxide.enableZshIntegration`
only does anything when `programs.zsh.enable = true` — it works by appending
to the `.zshrc` Home Manager itself generates. Since Home Manager doesn't own
`.zshrc` here, that option would be a silent no-op. Instead, the line
`eval "$(zoxide init zsh)"` was appended to `~/.zshrc` directly, by hand.
Kitty's integration is different — see above — which is why it *could* use
the normal option.

**The question that prompted this section**: if Home Manager generated
`.zshrc`, how would it ever get *loaded* — isn't there a bootstrapping
problem? No, and here's why:

- Home Manager is not a running service. It's invoked by hand
  (`home-manager switch`, or the `nix build` + `./result/activate` pair
  above). Running it evaluates `home.nix` and writes out a **complete**,
  static `~/.zshrc` (as a symlink to an immutable file in `/nix/store`) —
  once, ahead of time. It is not regenerated or re-evaluated when a shell
  starts.
- After that, opening a terminal is completely ordinary: zsh starts, sources
  `~/.zshrc` like it always has, done. Nothing "Home Manager" needs to be
  running or resolvable at that moment — the generated file already has
  every alias, function, and init snippet baked into its text.
- The part that actually matters is **`PATH`**. Today, `nvim`, `zoxide`, etc.
  resolve because of this block already at the top of `~/.zshrc` (written by
  the Nix installer, before this config existed):

  ```sh
  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
  ```

  If Home Manager took over `.zshrc` generation, it would regenerate this
  entire file from scratch — and it automatically emits the equivalent
  session-var sourcing near the top of its own output. You wouldn't
  hand-maintain that block anymore; Home Manager would own and reproduce it
  every time you switch.

**If I do switch `.zshrc` over to Home Manager later:**

1. Add `programs.zsh.enable = true;` to `home.nix`, move existing
   aliases/exports/functions into `programs.zsh.shellAliases` /
   `initContent`, and switch `zoxide`/`kitty` integration over to
   `enableZshIntegration = true`.
2. Run the switch with the backup flag so the current hand-written file
   isn't just clobbered: `home-manager switch -b backup` (or pass the
   equivalent option if using the `nix build` + `./result/activate` path —
   check `home-manager switch --help` for the current flag name first).
   Old file ends up at `~/.zshrc.backup` for comparison/recovery.
3. The *first* switch after enabling this still needs to run from a shell
   that already has `nix` on `PATH` — true today via the block above — so
   there's no ordering problem there either.

## History

- `4b31166` — initial config: Neovim/LazyVim via Nix, migrated
  `bat`/`btop`/`fd`/`fzf`/`lazygit`/`neovim`/`ripgrep` off the imperative
  `nix profile`.
- `462528a` — added Kitty, wired to the shared Nerd Font.
- `03b7917` — added `mac-app-util` (Spotlight/Launchpad fix for Kitty).
- `9765362` — added `zoxide`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A standalone [Home Manager](https://nix-community.github.io/home-manager/)
flake managing a slice of this user's environment on **two machines** — no
`nix-darwin`, no NixOS. Started as "Neovim/LazyVim via Nix" on a Mac and grew
to include Kitty, zsh and a handful of CLI tools; a second configuration for
an x86_64-linux laptop (Regolith/sway) was added later. Full rationale and
history are in `README.md`; this file is the quick-reference for making
changes.

Two outputs: `homeConfigurations."miguel@mac"` (`aarch64-darwin`, aliased as
`"miguel"`) and `homeConfigurations."miguel@clafoutis02"` (`x86_64-linux`).
A third, `homeConfigurations."hmtest@clafoutis02"`, is a throwaway no-sudo
test user on the Linux laptop for bringing up a Regolith-free sway desktop
(`sway.nix`); see `README.md`'s "Testing a Regolith-free desktop".

## Commands

Apply any change to the `.nix` files or `nvim/` — nothing takes effect until
this runs. Name the configuration for the machine you are on:

```sh
# macOS
nix build .#homeConfigurations."miguel@mac".activationPackage -L
./result/activate

# clafoutis02
nix build .#homeConfigurations."miguel@clafoutis02".activationPackage -L
./result/activate
```

Only one of the two can be *built* on a given machine, but both can be
**evaluated** anywhere, which is enough to catch most mistakes:

```sh
nix eval .#homeConfigurations."miguel@mac".config.home.homeDirectory
```

Update flake inputs (`nixpkgs`, `home-manager`, `mac-app-util`) and commit
the resulting `flake.lock`:

```sh
nix flake update
```

Validate the Neovim config after touching `nvim/` (installs/updates plugins,
then runs LazyVim's health checks headlessly):

```sh
nvim --headless "+Lazy! sync" +qa
nvim --headless "+checkhealth lazyvim" +qa
```

Two things `checkhealth` alone won't catch:
- **Plain startup errors.** `nvim --headless +qa` with no file arg, checked for
  stderr output, catches a plugin spec failing to load (e.g. `{ import =
  "lazyvim.plugins.extras.lang.X" }` where `X` doesn't exist in the
  installed LazyVim version — this happened once with `lang.lua`, which
  got folded into core and removed as a standalone extra between
  versions). `checkhealth` didn't flag it; only the raw startup stderr did.
- **LSP servers install lazily, on first buffer of a matching filetype** —
  not during `Lazy! sync`, which only installs/updates *plugins*. To verify
  an LSP actually attaches after adding a language extra, open a real file
  of that type and poll `vim.lsp.get_clients()`, e.g.:
  ```sh
  nvim --headless path/to/sample.ts -c 'lua vim.wait(15000, function() return #vim.lsp.get_clients() > 0 end, 500); print(vim.inspect(vim.lsp.get_clients()))' -c 'qa!'
  ```
  Give it real time (15s+) — Mason installing a server via npm is much
  slower than a short fixed sleep.

## Architecture

- `flake.nix` — inputs (`nixpkgs-unstable`, `home-manager`, `mac-app-util`)
  and both `homeConfigurations` outputs, built through `mkPkgs` / `mkHome`
  helpers. `pkgs` is built with `import nixpkgs { inherit system;
  config.allowUnfreePredicate = ...; }` rather than plain
  `nixpkgs.legacyPackages.${system}`, scoped to allow just `acli` (unfree).
  Adding another unfree package means adding its name to that predicate's
  list, not flipping on `allowUnfree = true` wholesale. **The predicate
  lists both `"acli"` and `"acli-unwrapped"`** — nixpkgs FHS-wraps `acli` on
  Linux and it is the inner derivation that carries the license, so listing
  only `"acli"` evaluates on Darwin and fails on Linux.
- `common.nix` — everything genuinely shared: `home.packages`, the
  `home.file` entry that wires up `nvim/`, `programs.{zsh,zoxide,starship,
  fzf}`, and the platform-neutral half of `programs.kitty`.
- `darwin.nix` / `linux.nix` — the per-host halves: home directory, Kitty
  font+theme, the Nix shell bootstrap (different paths per installer), the
  per-host Neovim overlays, and each platform's keyboard/font handling.
  **`mac-app-util` is imported only by the macOS module list**, since it
  builds its trampolines with `osacompile`.
- `sway.nix` — plain sway desktop (sway config, waybar, fuzzel, mako,
  kanshi, swayidle/swaylock, XKB layouts and `~/.local/bin` helpers from
  `sway/`). **Imported only by `hmtest@clafoutis02`.** `sway` and `swaylock`
  are `package = null` — the binaries come from the system (host GPU stack,
  host PAM); Home Manager writes their config only. Hence `checkConfig =
  false`: validate by hand with `sway --validate -c
  result/home-files/.config/sway/config`. `swayidle`'s service PATH holds only
  bash, so commands it runs need absolute `/usr/bin/...` paths.
  `targets.genericLinux.enable` is set there so Nix-built kitty can use the
  GPU after a one-time `sudo non-nixos-gpu-setup`.
- `nvim/` — the LazyVim starter template, git-tracked here. Wired into
  `~/.config/nvim` via `home.file` with `recursive = true`, which symlinks
  each file individually rather than symlinking the whole directory in one
  shot. That distinction matters: `lazy.nvim` needs to *write*
  `lazy-lock.json` inside `~/.config/nvim` at runtime, which only works if
  the directory itself is real (not a symlink into the read-only Nix
  store).
- `nvim-darwin/` and `nvim-linux/` — per-host plugin specs layered on top of
  `nvim/` as individual `home.file` entries targeting
  `.config/nvim/lua/plugins/<name>.lua`. `lazy.nvim` merges everything it
  finds under `lua/plugins/`, so extra files just work. This is how the two
  machines keep different colorschemes and language tooling while sharing one
  starter config. Note `nvim/lua/plugins/` holds only what is wanted on
  *both*.
- LazyVim's plugins are **not** Nix-managed — `lazy.nvim` installs/updates
  its own plugins under `~/.local/share/nvim`, independent of this flake.
  Nix's job is limited to supplying the `neovim` binary, LazyVim's runtime
  deps (`ripgrep`, `fd`, `lazygit`, `tree-sitter` CLI, `nodejs`, `python3`, a
  Nerd Font), and the starter config files themselves.
- `mac-app-util` (module imported in `flake.nix`) generates real
  "trampoline" `.app` bundles in `~/Applications/Home Manager Trampolines/`
  for any GUI app added to `home.packages` (currently just Kitty). This
  exists because `/nix` is mounted with the `nobrowse` flag, so Spotlight
  never indexes app bundles that live there, even when symlinked into
  `~/Applications`.
- `~/.zshrc` (plus `.zshenv`/`.zprofile`) **is** managed here
  (`programs.zsh.enable = true`) — generated, same rule as `kitty.conf`
  below: don't hand-edit it, changes go in `common.nix`'s `programs.zsh`
  block and get overwritten on the next activate. `zoxide`/`starship`/`fzf`
  all use real `enableZshIntegration = true` rather than hand-appended
  `eval` lines. See the `~/.zshrc is Home Manager's` section of `README.md`
  for the full option-by-option mapping.

## Working conventions specific to this repo

- **Don't default to `home.file` for anything a macOS *system* picker needs
  to discover** (Input Sources, and presumably similar system UIs) —
  `home.file`'s symlinks-into-`/nix/store` are invisible to at least the
  Keyboard Input Sources picker, the same class of problem `mac-app-util`
  exists to solve for Spotlight/Launchpad and GUI `.app` bundles.
  `home.activation.installQwertyFrLayout` in `darwin.nix` is the workaround
  pattern: `cp -RL` real files into place on every activation, then
  `chmod -R u+w` (required — `cp -RL` otherwise carries over the Nix
  store's read-only mode, which then blocks the *next* activation's
  cleanup). See the QWERTY-fr entry in `README.md` for the full story,
  including that a full **restart** (not just logout) was needed before
  System Settings picked it up, and an unrelated `osacompile`/AppleScript
  fault that showed up during the same debugging session and cleared on
  its own after that same restart.
- Packages `bat`, `btop`, `fd`, `fzf`, `lazygit`, `neovim`, `ripgrep` used to
  be installed imperatively via `nix profile install`; they were removed
  from that profile (`nix profile remove`) when brought into `common.nix`, to
  avoid two overlapping sources of truth. Don't reintroduce a package here
  that's also sitting in the imperative profile — check `nix profile list`
  first if unsure.
- Edit `~/.config/kitty/kitty.conf` never directly — it's generated from the
  `programs.kitty.settings` blocks in `common.nix` + `darwin.nix`/`linux.nix`
  and gets overwritten on the
  next `./result/activate`. Same rule for `~/.zshrc`/`.zshenv`/`.zprofile`
  and anything else under `home.file` or a `programs.*` module.
- New files under `nvim/`, `nvim-darwin/`, `nvim-linux/` (or anywhere else
  referenced by a local path in the flake) must be `git add`ed before
  `nix build` — flakes only copy
  git-tracked content into the store when evaluating a local flake, so an
  untracked file is silently invisible to the build until staged. Bit us
  once already: `nvim/lua/plugins/colorscheme.lua` didn't take effect until
  `git add`ed, even though the build succeeded.
- Nerd Font `font_family` values in `programs.kitty.settings` must use the
  **`Mono`** variant (e.g. `"FiraCode Nerd Font Mono"`), not the plain
  family name — **on macOS**; see `README.md` for why, and the Linux note
  below.
- **Anything Linux-only that touches the window manager does not belong
  here.** `linux.nix` owns the CLI/editor/terminal layer; XKB symbol files,
  Regolith `sway/config.d` partials and the `~/.local/bin` helper scripts are
  deployed imperatively by `~/.config/sway/install.sh` on that machine. Never
  add a `programs.sway` / `wayland.windowManager.sway` block to `linux.nix`
  or `common.nix`: Regolith runs `sway -c /etc/regolith/sway/config` and never
  reads `~/.config/sway/config`. The exception is `sway.nix`, imported only by
  `hmtest@clafoutis02`; its `sway/xkb/` and `sway/bin/` are copies of
  `~/.config/sway/` and must be kept in step by hand until it is promoted.
- **On Linux, a font in `home.packages` is invisible without
  `fonts.fontconfig.enable = true`** (set in `linux.nix`). macOS links fonts
  into `~/Library/Fonts` on its own; Linux does not, and the symptom is
  silent — Kitty falls back and every Nerd Font glyph renders as tofu.
- **Kitty's Nerd Font `Mono`-variant gotcha is macOS-only.** It is a CoreText
  resolution failure; under fontconfig the plain family resolves fine, so
  `linux.nix` deliberately does not mirror the workaround.

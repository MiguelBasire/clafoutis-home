# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A standalone [Home Manager](https://nix-community.github.io/home-manager/)
flake managing a slice of this macOS user's environment — no `nix-darwin`.
Started as "Neovim/LazyVim via Nix" and grew to include Kitty and a handful
of CLI tools. Full rationale and history are in `README.md`; this file is
the quick-reference for making changes.

## Commands

Apply any change to `home.nix` or `nvim/` — nothing takes effect until this
runs:

```sh
nix build .#homeConfigurations.miguel.activationPackage -L
./result/activate
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

## Architecture

- `flake.nix` — inputs (`nixpkgs-unstable`, `home-manager`, `mac-app-util`)
  and the single `homeConfigurations."miguel"` output. `system` is
  hardcoded to `"aarch64-darwin"`, not parameterized.
- `home.nix` — all managed state: `home.packages` (CLI tools), the
  `home.file` entry that wires up `nvim/`, and `programs.{kitty,zsh,zoxide,
  starship,fzf}`.
- `nvim/` — the LazyVim starter template, git-tracked here. Wired into
  `~/.config/nvim` via `home.file` with `recursive = true`, which symlinks
  each file individually rather than symlinking the whole directory in one
  shot. That distinction matters: `lazy.nvim` needs to *write*
  `lazy-lock.json` inside `~/.config/nvim` at runtime, which only works if
  the directory itself is real (not a symlink into the read-only Nix
  store).
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
  below: don't hand-edit it, changes go in `home.nix`'s `programs.zsh`
  block and get overwritten on the next activate. `zoxide`/`starship`/`fzf`
  all use real `enableZshIntegration = true` rather than hand-appended
  `eval` lines. See the `~/.zshrc is Home Manager's` section of `README.md`
  for the full option-by-option mapping.

## Working conventions specific to this repo

- Packages `bat`, `btop`, `fd`, `fzf`, `lazygit`, `neovim`, `ripgrep` used to
  be installed imperatively via `nix profile install`; they were removed
  from that profile (`nix profile remove`) when brought into `home.nix`, to
  avoid two overlapping sources of truth. Don't reintroduce a package here
  that's also sitting in the imperative profile — check `nix profile list`
  first if unsure.
- Edit `~/.config/kitty/kitty.conf` never directly — it's generated from the
  `programs.kitty.settings` block in `home.nix` and gets overwritten on the
  next `./result/activate`. Same rule for `~/.zshrc`/`.zshenv`/`.zprofile`
  and anything else under `home.file` or a `programs.*` module.
- New files under `nvim/` (or anywhere else referenced by a local path in
  the flake) must be `git add`ed before `nix build` — flakes only copy
  git-tracked content into the store when evaluating a local flake, so an
  untracked file is silently invisible to the build until staged. Bit us
  once already: `nvim/lua/plugins/colorscheme.lua` didn't take effect until
  `git add`ed, even though the build succeeded.
- Nerd Font `font_family` values in `programs.kitty.settings` must use the
  **`Mono`** variant (e.g. `"FiraCode Nerd Font Mono"`), not the plain
  family name — see `README.md` for why.

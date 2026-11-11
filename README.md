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

- **`gh`** (GitHub CLI, from nixpkgs) and **`bbt`** (Bitbucket Cloud CLI,
  custom-packaged — see below).

  Getting to `bbt` took two wrong turns, worth recording so they don't get
  repeated:
  1. nixpkgs' `bitbucket-cli` package only talks to self-hosted Bitbucket
     Server/Data Center's REST API, not bitbucket.org (cloud).
  2. `acli` (Atlassian's own official CLI) looked right from its homepage
     (`developer.atlassian.com/cloud/acli`), but `acli --help` shows it
     only covers Jira, Confluence, Guard, admin, and Rovo Dev — **no
     Bitbucket subcommand at all**. It got added anyway on the strength of
     the homepage URL alone, without checking the actual command surface
     first; that was the mistake. (This did also require scoping
     `config.allowUnfreePredicate` to `acli` in `flake.nix`, since it's
     unfree-licensed — all reverted along with removing the package.)

  `bbt` ([romaintb/bbt](https://codeberg.org/romaintb/bbt), MIT, Go) is a
  small, actively-maintained, purpose-built "`gh` for Bitbucket" — not in
  nixpkgs, so it's packaged directly in `home.nix` via `pkgs.buildGoModule`
  + `pkgs.fetchgit` against Codeberg (Gitea-hosted, hence `fetchgit` rather
  than `fetchFromGitHub`), pinned to a commit with both `src.hash` and
  `vendorHash` recorded. Supports Bitbucket personal access tokens, not
  just the app passwords Atlassian is deprecating through 2026.

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

  **Project workspaces stay out of this repo.** A project's Kitty layout
  (tabs, services, startup order) is a `.kitty-session` file at that
  project's root — kept out of its git via `.git/info/exclude` when it's
  personal. This repo only ships the generic glue, both in `home.nix`:
  - `ws` — run from anywhere in a project; opens its `.kitty-session` (git
    root, else `$PWD`) in a new Kitty instance.
  - `devpane <cmd>` — for session `launch` lines; runs `<cmd>` inside the
    project's `nix develop` shell, then leaves a prompt there.

  In the session file, use `cd .` after each `new_tab` (Kitty resolves
  relative `cd` paths against the session file's directory, and a `cd`
  before the first `new_tab` is discarded) and bare `devpane` in `launch`
  lines — no absolute paths needed. A Mercio-specific session, shortcut and
  Spotlight launcher used to live here; they moved to the Mercio repo.

- **QWERTY-fr keyboard layout** ([qwerty-fr/qwerty-fr](https://github.com/qwerty-fr/qwerty-fr),
  MIT, pinned to a specific commit via `pkgs.fetchFromGitHub`). **Not** a
  `home.file` entry, unlike everything else here — that was tried first
  (per-file symlinks into `/nix/store`, same pattern as `nvim/`) and the
  layout never appeared in System Settings' Input Sources picker, even
  after a logout. Root cause: the picker doesn't discover a keyboard
  layout bundle whose contents are symlinks into the (`nobrowse`) Nix
  store — the same class of problem `mac-app-util` exists to solve for
  GUI `.app` bundles, just hitting a different macOS subsystem. Fix is
  `home.activation.installQwertyFrLayout`, which `cp -RL`'s the fetched
  bundle into `~/Library/Keyboard Layouts/` as real files on every
  activation (then `chmod -R u+w`, since `cp -RL` otherwise preserves the
  Nix store's read-only mode, which blocks the *next* activation's own
  cleanup `rm -rf`).

  Confirmed working after a **full restart** — a logout/login was not
  enough for System Settings to pick up the newly-real files. (A
  separate, unrelated macOS fault showed up during this same debugging
  session — `osacompile` refusing to compile any AppleScript "Standard
  Additions" command like `do shell script`, which broke `mac-app-util`'s
  Kitty trampoline regeneration mid-activation. Also cleared by the same
  restart. If `./result/activate` ever dies inside `trampolineApps` with
  an AppleScript compilation error, that's this — restart the Mac, don't
  debug the Nix config.)

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

## Tweaking the Neovim config

Everything under `~/.config/nvim` is a read-only symlink into `/nix/store` —
never edit there. The source of truth is `nvim/` in this repo:

```sh
cd ~/.config/home-manager
$EDITOR nvim/lua/plugins/whatever.lua
git add nvim/        # new files are invisible to the flake until staged
nix build .#homeConfigurations.miguel.activationPackage -L && ./result/activate
nvim                 # lazy.nvim installs/removes plugins on startup
git commit
```

Where each kind of change goes:

- **LazyVim extra** (anything listed in `:LazyExtras`) → an
  `{ import = "lazyvim.plugins.extras.…" }` line in
  `nvim/lua/plugins/extras.lua`. Use `:LazyExtras` only to *browse*:
  pressing `x` there writes to `~/.config/nvim/lazyvim.json`, a runtime file
  outside this repo, so the choice silently never makes it into git.
- **New plugin or plugin tweak** → a new file in `nvim/lua/plugins/`
  returning a lazy.nvim spec.
- **Options / keymaps / autocmds** → `nvim/lua/config/{options,keymaps,autocmds}.lua`.
- **LSP / formatter / linter binaries** → Mason, by default. When Mason
  can't install one or it breaks — `nil` (no Mason build here), and
  `ruby-lsp`/`rubocop` (Mason builds their native gems against whatever
  `/nix/store` Ruby is on `PATH`, so they fail with "linked to incompatible
  libruby" after every Ruby bump) — install it via `home.packages` in
  `home.nix` instead, and set `<server> = { mason = false }` in
  `extras.lua`'s `nvim-lspconfig` opts. Without `mason = false`, LazyVim
  still routes the server through Mason and the Nix binary is ignored.
  Uninstall any broken Mason copy too: Mason's bin dir is prepended to
  Neovim's `PATH`, so it shadows the Nix one.
  See "Mason or Nix?" below for how to decide.
- **Plugin updates** → `:Lazy update`, then copy the updated
  `~/.config/nvim/lazy-lock.json` into `nvim/` if you want versions pinned
  in git.

Verify: `nvim --headless +qa` must print nothing on stderr, then open a real
file of the language and check `:LspInfo` (or the `vim.lsp.get_clients()`
one-liner in `CLAUDE.md`).

### Mason or Nix?

Default to **Mason**. Move a tool to **Nix** when any of these hold:

1. **Mason fails.** `:Mason` shows an install failure or no build for
   aarch64-darwin (`nil`), `:LspLog` / `:messages` show `linked to
   incompatible libruby`, `dyld: Library not loaded`, `ENOENT`, or
   `:LspInfo` shows no client on a file that should have one.
2. **It's tied to a Nix-provided language runtime.** Mason builds against
   whatever `ruby`/`python3` is on `PATH` at install time — a specific
   `/nix/store/...` path — so the install breaks when Nix bumps or
   garbage-collects that runtime. Fragile: Ruby gems with native extensions
   (`ruby-lsp`, `rubocop`, `erb-lint`), Python tools whose venv points at a
   Nix Python. Generally fine on Mason: npm-based tools (`vtsls`, `jsonls`,
   `marksman`, `prettier`) and self-contained Go/Rust binaries (`taplo`,
   `gopls`, `stylua`).
3. **It's used outside Neovim too** (shell, git hooks, scripts) — Nix puts
   one version on `PATH` for everything; Mason's copies are Neovim-only.
4. **You want the version pinned in git** — `flake.lock` pins Nix packages;
   Mason installs whatever is latest.

Switching: `nix search nixpkgs <name>` → add to `home.packages` → set
`<server> = { mason = false }` in `extras.lua` → uninstall the Mason copy →
rebuild → check `:LspInfo`.

In practice: add the extra, open a file, check `:LspInfo`. Works → stay on
Mason. Breaks, or it's a native-extension Ruby/Python tool → Nix. `erb-lint`
is still on Mason and is the likely next candidate.

### Per-project config

lazy.nvim loads a **`.lazy.lua`** file automatically (`local_spec = true` is
its default): on startup it walks up from the current directory, and the
first `.lazy.lua` it finds is appended to the plugin specs — same format as
a file in `nvim/lua/plugins/`, just living in the project:

```lua
-- ~/code/some-project/.lazy.lua
return {
  { import = "lazyvim.plugins.extras.lang.python" },  -- extra only this project needs
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { rubocop = { enabled = false } } },  -- disable a server here
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { ruby = { "standardrb" } } },  -- different formatter
  },
}
```

It's read through `vim.secure.read`, so Neovim asks to trust it the first
time (and after every change) — answer `a` to allow.

Alternatives for plain settings:
- **`.editorconfig`** — built into Neovim; indent, tab width, final newline.
  Best for anything the whole team should share.
- **`.nvim.lua`** — Neovim's built-in exrc, plain Lua. Currently **off**
  (`exrc = false`); enabling it means adding `vim.o.exrc = true` to
  `nvim/lua/config/options.lua` and rebuilding.

If the file shouldn't be committed to the project, add `.lazy.lua` (or
`.nvim.lua`) to that project's `.gitignore`, or globally to
`~/.config/git/ignore`.

Rule of thumb: every project → this repo; one project → its `.lazy.lua`;
team-shared style → `.editorconfig`.

## Bootstrapping a new project (Rust example)

This repo is the machine layer every project gets for free: Neovim +
LazyVim, Kitty, git/`gh`, Nix with flakes enabled, `ws`/`devpane`. Nothing
language- or project-specific goes here — that lives in the project:

| What | Where |
|---|---|
| Toolchain (`cargo`, `rustc`, `rust-analyzer`, ...) | the project's `flake.nix` devShell |
| Neovim language support | `extras.lua` here if it's a regular language for you, else the project's `.lazy.lua` |
| Kitty workspace | the project's `.kitty-session` (`.git/info/exclude` if personal) |

**1. Toolchain** — in the project's `flake.nix`, so each project pins its
own Rust version and teammates/CI get the same one:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.aarch64-darwin; in {
      devShells.aarch64-darwin.default = pkgs.mkShell {
        packages = with pkgs; [ cargo rustc rust-analyzer clippy rustfmt ];
        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";  # std source for rust-analyzer
      };
    };
}
```

(Need a specific toolchain or nightly via `rust-toolchain.toml`? That's
what overlays like `oxalica/rust-overlay` are for — check their current
setup before adding one.)

**2. Neovim** — LazyVim's `lang.rust` extra
(`{ import = "lazyvim.plugins.extras.lang.rust" }`). It uses
**rustaceanvim**, which does *not* install rust-analyzer via Mason: it takes
whatever `rust-analyzer` is on `PATH` (and warns "rust-analyzer not found in
PATH" otherwise). So the server comes from the project's flake and matches
its toolchain — the "Nix, not Mason" case above, with no `mason = false`
needed. Mason only installs `codelldb` (debugger). It also brings
`crates.nvim` (dependency versions inline in `Cargo.toml`).

Catch: Neovim must be started **inside the dev shell**, or rust-analyzer
isn't on `PATH` — `devpane nvim` does exactly that.

**3. Workspace** — the project's `.kitty-session`:

```
new_tab dev
cd .
layout splits
launch --title nvim devpane nvim
focus
launch --location=vsplit --title cargo devpane 'cargo watch -x check'

new_tab shell
cd .
launch --title shell devpane
```

(`cargo watch` isn't part of cargo — add `cargo-watch` to the flake's
`packages`.)

**Day one, from an empty folder:**

```sh
mkdir ~/Projects/foo && cd ~/Projects/foo && git init
$EDITOR flake.nix                 # the devShell above
git add flake.nix                 # flakes only see git-tracked files
nix develop --command cargo init  # Cargo.toml + src/main.rs
$EDITOR .kitty-session            # optional
ws
```

The first `ws` is slow (Nix downloads the toolchain); cached after that.

## `~/.zshrc` is Home Manager's

As of the "Bring `.zshrc` under Home Manager" commit (see History),
`programs.zsh.enable = true;` and `.zshrc` (plus
`.zshenv`/`.zprofile`) are generated files — symlinks into `/nix/store`, same
as `kitty.conf` and `~/.config/nvim`. **Don't hand-edit `.zshrc` anymore** —
it gets silently overwritten on the next `./result/activate`. Everything
that used to be a manual line lives in `home.nix` now:

| What | Where in `home.nix` |
|---|---|
| Nix multi-user installer's shell bootstrap (`nix-daemon.sh`) | `programs.zsh.envExtra` (→ `~/.zshenv`), sourcing `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`. Originally copied verbatim into `initContent`, but that block pointed at `~/.nix-profile`, which is Home Manager's profile and has no `nix-daemon.sh` — a silent no-op that only went unnoticed because `/etc/zshrc` did the real work. The macOS 27.0.1 update reset `/etc/zshrc` to Apple's stock copy and Nix vanished from every new shell; `~/.zshenv` is user-owned, so OS updates can't undo it. |
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

- `5a9f763` — initial config: Neovim/LazyVim via Nix, migrated
  `bat`/`btop`/`fd`/`fzf`/`lazygit`/`neovim`/`ripgrep` off the imperative
  `nix profile`.
- `9ca03ba` — added Kitty, wired to the shared Nerd Font.
- `aed0bd7` — added `mac-app-util` (Spotlight/Launchpad fix for Kitty).
- `fb277fb` — added `zoxide`.
- `bca6a18` — switched the Nerd Font from JetBrains Mono to Fira Code.
- `2da7a48` → `f53be55` → `ab10ff9` → `d280b92` — theme churn: Gruvbox Dark
  on Kitty, then matched to Tokyo Night Moon (Neovim's default), then
  Starship added with the Tokyo Night preset, then everything (Kitty,
  Neovim, Starship) settled on Gruvbox together.
- `cc40662` — added `zsh-autosuggestions` + `fzf-tab` (fixed-path symlink
  workaround, since zsh wasn't Home-Manager-owned yet at this point).
- `abf38ad` / `7326aa7` — fixed + documented the Kitty Nerd Font `Mono`
  variant gotcha.
- `0588a3b` — brought `.zshrc` under Home Manager; see the dedicated
  section above for the full mapping and migration mechanics.
- `230a2d1` — added `gh` and `acli` (GitHub/Bitbucket Cloud CLIs); required
  scoping `config.allowUnfreePredicate` to `acli` in `flake.nix` since it's
  an unfree package.
- **Two full-history rewrites, not individual commits.** All commits were
  rewritten (via `git-filter-repo` + a root `git rebase --exec 'commit
  --amend -S'`) first to fix the author identity to `Miguel Basire
  <miguel.basire@gmail.com>` and SSH-sign every commit, then again to swap
  that email for the GitHub-provided
  `413615+MiguelBasire@users.noreply.github.com` before this repo went
  public, keeping the real address out of scrapers while commits still
  verify against the same SSH key. Both rewrites changed every hash in
  this repo — hashes referenced above are current as of the second
  rewrite; anything cited elsewhere (issues, old clones, etc.) predating
  it won't resolve.
- Swapped `acli` for `bbt` (custom-packaged) after discovering `acli` has
  no Bitbucket support at all — see the `gh`/`bbt` entry above for the
  full story. Also reverted the `config.allowUnfreePredicate` scoping in
  `flake.nix` that `acli` had required.

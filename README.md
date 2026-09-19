# Home Manager config

Standalone [Home Manager](https://nix-community.github.io/home-manager/) setup
— no `nix-darwin`, no NixOS, just a flake that manages a chunk of the user
environment declaratively. Started as "configure Neovim with LazyVim through
Nix" on a Mac, and now covers two machines.

| Configuration | System | Machine |
|---|---|---|
| `miguel@mac` (alias: `miguel`) | `aarch64-darwin` | the MacBook |
| `miguel@clafoutis02` | `x86_64-linux` | TUXEDO laptop, Regolith/sway on Wayland |
| `hmtest@clafoutis02` | `x86_64-linux` | same laptop, throwaway test user for a Regolith-free sway desktop |

## Layout

```
flake.nix     -- inputs and the homeConfigurations outputs for both machines
common.nix    -- everything genuinely shared: packages, Neovim wiring, zsh,
                 zoxide/fzf/starship, the platform-neutral Kitty settings
darwin.nix    -- macOS only: QWERTY-fr layout, Gruvbox theming, Fira Code,
                 the macOS Nix shell bootstrap
linux.nix     -- Linux only: fontconfig, Nord theming, Monoid, the Linux Nix
                 shell bootstrap
nvim/         -- the LazyVim starter template, shared by both machines,
                 symlinked file-by-file into ~/.config/nvim
nvim-darwin/  -- Neovim plugin specs layered on top of nvim/ on macOS only
nvim-linux/   -- Neovim plugin specs layered on top of nvim/ on Linux only
sway.nix      -- plain sway desktop (no Regolith); hmtest@clafoutis02 only
sway/         -- XKB layouts and ~/.local/bin helpers deployed by sway.nix
```

## Applying changes

On the Mac:

```sh
nix build .#homeConfigurations."miguel@mac".activationPackage -L
./result/activate
```

On clafoutis02:

```sh
nix build .#homeConfigurations."miguel@clafoutis02".activationPackage -L
./result/activate
```

(Equivalent to `home-manager switch --flake .#miguel@mac`, just via the flake's
own build output so it doesn't depend on the `home-manager` CLI already being
on `PATH`.) Commit `flake.lock` changes along with the rest — that's what
pins exact package versions.

## What is deliberately *not* shared

The split exists because the two machines genuinely diverge. Adding something
to `common.nix` that only makes sense on one of them is the main way to break
this repo.

| | macOS | clafoutis02 |
|---|---|---|
| Terminal theme | Gruvbox Dark | Nord |
| Terminal font | FiraCode Nerd Font Mono 14 | Monoid Nerd Font 10 |
| Neovim colorscheme | gruvbox (`nvim-darwin/`) | LazyVim default (no override) |
| Starship palette | upstream Gruvbox Rainbow | same preset, slate/blue palette |
| Extra Neovim plugins | — | Kotlin LSP swap, nvim-metals, nvim-training |
| QWERTY-fr | `~/Library/Keyboard Layouts` bundle | XKB, via `~/.config/sway/install.sh` |
| Fonts | linked automatically by HM | needs `fonts.fontconfig.enable` |

### The Linux scope boundary

`linux.nix` owns the **CLI / editor / terminal** layer only. The
**window-manager** layer — XKB symbol files, Regolith `sway/config.d`
partials, and the `~/.local/bin` helper scripts (`rescan-displays`,
`dock-diag`, `screenshot`) — stays with `~/.config/sway/install.sh`, which
deploys it imperatively.

Do not add a `programs.sway` block. Regolith starts sway with
`sway -c /etc/regolith/sway/config` and never reads `~/.config/sway/config`,
so Home Manager would generate a file nothing loads. (An abandoned Home
Manager generation on that machine did exactly this — it is still in the
store, unactivated.)

The one exception is `sway.nix`, which is imported **only** by
`hmtest@clafoutis02` — see [Testing a Regolith-free desktop](#testing-a-regolith-free-desktop).
Until that is promoted, `~/.config/sway/install.sh` stays the source of truth
for miguel; `sway/xkb/` and `sway/bin/` here are copies of it and must be kept
in step by hand.

## Testing a Regolith-free desktop

Goal: replace Regolith with plain sway configured entirely by Home Manager,
without risking the working session. `hmtest` is a throwaway user **without
sudo** on the same laptop; it gets its own home and nix profile, so nothing it
does touches miguel's `~/.config`, GDM, or the Regolith session.

`sway.nix` writes config only for the two binaries that must come from the
system — `sway` (needs the host GPU stack) and `swaylock` (needs the host PAM)
— and installs everything else (waybar, fuzzel, mako, kanshi, swayidle,
grimshot, foot, ...) from nixpkgs.

**Before installing anything with apt**, check whether Regolith's own sway
package conflicts with Ubuntu's — it may, and removing it breaks the working
session:

```sh
dpkg -S "$(command -v sway)"    # which package owns the sway binary
command -v swaylock             # present? if not: apt install -s swaylock (simulate first)
apt install -s swaylock         # -s = simulate: look for "REMOVE" lines
```

Nothing in the test needs apt as long as `/usr/bin/sway` exists (Regolith's
sway is still sway and accepts any `-c`).

### Once

```sh
sudo adduser hmtest                  # no sudo group
sudo chsh -s /usr/bin/zsh hmtest     # so .zprofile loads Home Manager's session variables
grep allowed-users /etc/nix/nix.conf # unset or containing hmtest
```

### Each iteration

As miguel, build (hmtest can't read this repo — the result is a
world-readable store path instead):

```sh
nix build .#homeConfigurations."hmtest@clafoutis02".activationPackage -L
readlink -f result
```

Optional quick check, still as miguel — the config parses under sway:

```sh
sway --validate -c result/home-files/.config/sway/config
```

Then on a text console (`Ctrl+Alt+F3`), log in as `hmtest` and:

```sh
/nix/store/…-home-manager-generation/activate   # the path from readlink
XDG_CURRENT_DESKTOP=sway XDG_SESSION_DESKTOP=sway sway
```

Starting from a TTY needs no session file, so GDM is untouched. `$mod+Shift+e`
exits back to the console; `Ctrl+Alt+F1`/`F2` returns to miguel's session.

The first activation prints a warning that the system is not set up to use
the GPU with Nix packages, with a `sudo …/non-nixos-gpu-setup` command. Nix's
kitty won't start until that has been run once (by miguel — hmtest has no
sudo); `$mod+Ctrl+Return` opens `foot`, which needs no GPU. The setup only adds
a `/run/opengl-driver` symlink and a systemd unit that recreates it at boot.

### Keybindings

`sway.nix` ports every binding from Regolith 3.4's
`/usr/share/regolith/{common,sway}/config.d/` (snapshot in
`~/.config/regolith-snapshot/`) plus the overrides in `~/.config/regolith3`,
replacing Home Manager's i3-style defaults outright. `$mod+?` lists them all.
Same keys, different program behind them:

| Keys | Regolith | Here |
|---|---|---|
| `$mod+Space` / `+Shift+Space` | ilia apps / commands | fuzzel / `fuzzel --list-executables-in-path` |
| `$mod+Ctrl+Space`, `$mod+.` | ilia windows, i3-swap-focus | swayr (window by name, last focused window) |
| `$mod+Alt+Space` | ilia file search (Tracker) | `file-search`: fd + fuzzel, names only |
| `$mod+?` | ilia keybinding viewer | generated list in fuzzel |
| `$mod+n` | rofication viewer | `makoctl restore` (last dismissed notification) |
| `` $mod+` `` (+Shift / +Alt) | childe | `next-free-workspace`, same flags |
| `$mod+c` / `d` / `w` / `b` | regolith-control-center panels | gnome-control-center / wdisplays / nm-connection-editor / blueman |
| `$mod+Escape` | gtklock | system swaylock |
| `$mod+Shift+e` / `b` / `p` | gnome-session-quit | `swaymsg exit` / `systemctl reboot` / `poweroff` |
| `$mod+Shift+r` | regolith-look refresh | restart waybar, kanshi, swayrd |
| `$mod+Alt+q` | `kill -9` via xdotool (X11 only) | `kill -9` of the focused window's pid via swaymsg |
| `$mod+i` | toggle swaybar | toggle waybar |
| media keys | avizo | avizo (unchanged) |

Moved keys: gap size is `$mod+=` / `$mod+Shift+=` (Ctrl for the big step)
instead of `$mod+-` / `$mod++`, because on `fr_azerty_num` `minus` is
Shift+6 and `$mod+minus` would shadow `$mod+Shift+6` (move window to
workspace 6). Gone: `$mod+Alt+l` (Regolith look selector).

### Parity checklist

- [ ] keybindings match Regolith muscle memory (see above)
- [ ] kanshi profiles apply on each dock/monitor (`sway.nix` has all eight)
- [ ] `rescan-displays` / `dock-diag` / screenshot bindings
- [ ] both XKB layouts, per device
- [ ] lock (`$mod+Escape`), idle lock at 5 min, screens off at 10 min
- [ ] notifications (mako), tray (nm-applet), volume/brightness keys
- [ ] polkit prompts (needs apt `policykit-1-gnome`)
- [ ] screen sharing in the browser/Zoom (needs apt `xdg-desktop-portal-wlr`)
- [ ] kitty after the GPU setup

### Cleaning up

```sh
sudo userdel -r hmtest
sudo nix-collect-garbage
```

### `acli` and the unfree predicate

`acli` is unfree, and nixpkgs packages it differently per platform: on Darwin
the unfree derivation is `acli` itself, but on Linux `acli` is a `buildFHSEnv`
wrapper around `acli-unwrapped`, and it is the *inner* derivation that carries
the license. `flake.nix` therefore allows **both** names. Listing only `"acli"`
evaluates fine on the Mac and fails on Linux with `Refusing to evaluate package
'acli-unwrapped-...'`.

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

- **`gh`** (GitHub CLI) and **`acli`** (Atlassian's official CLI, covering
  Bitbucket Cloud/bitbucket.org). nixpkgs also has a `bitbucket-cli`
  package, but that one only talks to self-hosted Bitbucket Server/Data
  Center's REST API, not bitbucket.org — not what's wanted here, so it was
  swapped for `acli`. `acli` ships under an unfree license, which
  `flake.nix` allows via a `config.allowUnfreePredicate` scoped to just
  that package name (not a blanket `allowUnfree = true`), so any other
  unfree package added later still fails loudly instead of silently
  slipping through.

- **Kitty** (`programs.kitty`). Config is generated to
  `~/.config/kitty/kitty.conf` from the `settings` blocks in `common.nix` and
  the per-host file — edit
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

## `~/.zshrc` is Home Manager's

As of the "Bring `.zshrc` under Home Manager" commit (see History),
`programs.zsh.enable = true;` and `.zshrc` (plus
`.zshenv`/`.zprofile`) are generated files — symlinks into `/nix/store`, same
as `kitty.conf` and `~/.config/nvim`. **Don't hand-edit `.zshrc` anymore** —
it gets silently overwritten on the next `./result/activate`. Everything
that used to be a manual line lives in `common.nix` (or a per-host file) now:

| What | Where |
|---|---|
| Nix multi-user installer's shell bootstrap (`nix.sh`, `nix-daemon.sh`, `NIX_PATH` fallback) | `programs.zsh.initContent` at `lib.mkOrder 500` — **per host**, since the macOS and Linux installers lay their profile scripts down in different places. `darwin.nix` preserves the original hand-written block verbatim; `linux.nix` sources `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` instead |
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
- **The multi-system split.** `flake.nix` grew a second
  `homeConfigurations` entry for `x86_64-linux`, and `home.nix` was broken up
  into `common.nix` + `darwin.nix` + `linux.nix`. Four things blocked the
  Linux configuration outright before the split: the hardcoded
  `aarch64-darwin` system, the hardcoded `/Users/miguel` home directory, the
  Darwin-only `mac-app-util` module, and the `~/Library/Keyboard Layouts`
  activation script. A fifth, subtler one was the `allowUnfreePredicate`
  missing `acli-unwrapped` (see above). `homeConfigurations."miguel"` is kept
  as an alias for `"miguel@mac"` so the old command line still resolves.

# 🐧 Penguin Setup

Set up a development machine — Fish shell, Homebrew, a curated set of CLI
tools, and the configs to go with them — on Linux or macOS, in one command.

```bash
./setup.sh                    # install everything
./setup.sh --headless         # servers and containers: no desktop configs

./sync.sh pull                # repo      -> ~/.config
./sync.sh push                # ~/.config -> repo

test/run.sh debian --fast     # try the whole thing in a container
```

Everything that gets installed or synced lives in one file:
[`packages.conf`](packages.conf). That is the file you edit; the scripts do
not name a single package.

---

## Installation

**Fresh machine, one command:**

```bash
curl -fsSL https://raw.githubusercontent.com/Edzemundo/penguin_setup/main/starter.sh | bash
```

Add `-s -- --headless` for a server. This clones to
`~/.local/share/penguin_setup` and runs `setup.sh`. Re-running it updates the
checkout instead of failing.

**Or clone it yourself,** which is worth doing if you would rather read the
scripts first:

```bash
git clone https://github.com/Edzemundo/penguin_setup.git
cd penguin_setup
./setup.sh --dry-run          # see exactly what it would do
./setup.sh
```

Run it as **your normal user, not with sudo**. It refuses to start as root:
everything it installs belongs to one user, and the handful of commands that
need elevation call `sudo` themselves. Running the whole thing as root is what
used to leave root-owned files in `~/.config`.

### Options

| Flag | Effect |
|---|---|
| `--headless` | Skip desktop application configs and packages |
| `--dry-run` | Print what would change; change nothing |
| `--skip=brew,aur,uv,upgrade` | Skip named steps |
| `--upgrade` | Also upgrade already-installed brew packages |
| `--yes` | Never prompt |

### Supported platforms

| Platform | Native packages | Homebrew |
|---|---|---|
| macOS | — (Xcode CLT) | ✅ |
| Debian / Ubuntu | apt | ✅ |
| Fedora / RHEL | dnf | ✅ |
| Arch / Manjaro | pacman + yay | ✅ |

Homebrew provides the user-facing tools on every platform, so you get the same
versions everywhere. The native package manager only supplies build
dependencies and system integration.

---

## Keeping configs in sync

`sync.sh` moves config directories between the repo and `~/.config` in either
direction.

```bash
./sync.sh pull                # take the repo's configs
./sync.sh push                # send this machine's configs back to the repo

./sync.sh pull --dry-run      # preview, always available
./sync.sh push --only fish    # one directory
./sync.sh pull --headless     # skip desktop configs
```

Neither direction commits anything. `push` stops and shows you
`git status` so you can review the diff yourself.

### What keeps this safe

**`pull` backs up whatever it replaces** to
`~/.local/state/penguin_setup/backups/<timestamp>/`, keeping the last five
runs.

**`push` refuses to run if `config/` has uncommitted changes.** That is the
real safety net: it guarantees `git checkout -- config/` always undoes a push.
It also previews the whole operation first and asks before deleting more than
ten files.

**Machine-local state never moves.** Excluded paths are listed per directory
in `packages.conf` and are protected in *both* directions — rsync will not
delete something it was told to exclude. This is what keeps fisher's installed
plugins, `fish_variables`, atuin's history database and encryption key, and
nvim's `lazy-lock.json` out of the repo and safe from being overwritten.

### The ownership rule

Directories listed in `CONFIGS` are **owned by the repo**. A file you create
inside one will be deleted on the next `pull`. To keep local changes, either:

- put them in a `*.local` file (`ghostty/config.local`, `git/config.local`)
  and add the name to `EXCLUDES_<tool>` in `packages.conf`, or
- `push` them, so they become part of the repo.

Scope: this tool manages directories under `~/.config` and nothing else. Not
`~/.ssh/config`, not `~/.gitconfig`, not macOS `defaults write`.

---

## Editing what gets installed

Open [`packages.conf`](packages.conf). It has three parts.

**Packages** — one array per package manager:

```bash
BREW_PACKAGES=(atuin bat dust eza fd fzf ...)   # both platforms
BREW_PACKAGES_LINUX=(gcc)                       # additive, Linux only
APT_PACKAGES=(build-essential btop curl ...)
```

The rule, worth keeping to: **native package manager for build dependencies
and system integration, Homebrew for user-facing tools.** Listing a tool in
both gets you two copies at different versions and lets `PATH` decide which
one you actually run.

**Config directories** — with optional tags for where they apply:

```bash
CONFIGS=(
  fish              # everywhere
  kitty:desktop     # skipped by --headless
  zed:desktop
  # hypr:desktop,linux
)
```

Tags are `desktop`, `linux` and `macos`; combine with commas, all must match.
Adding a new config directory means creating `config/<name>/` and adding the
name here.

**Sync excludes** — anything machine-local:

```bash
SYNC_EXCLUDES_GLOBAL=( '.git/' '.DS_Store' '*.swp' )
EXCLUDES_fish=( fish_variables functions/ completions/ conf.d/ )
```

---

## Testing in a container

Linux paths can be exercised end to end without touching your machine. The
repo is bind-mounted read-only and copied inside the container, so a test run
cannot modify your working tree.

```bash
test/run.sh debian --fast     # ~1 min, skips Homebrew
test/run.sh debian            # full run including Homebrew
test/run.sh all               # debian, fedora and arch
test/run.sh arch --shell      # poke around by hand
test/run.sh --lint            # shellcheck, via container
```

`--fast` skips Homebrew, the AUR and uv. Homebrew-on-Linux in a container
builds from source when there is no bottle and dominates the runtime; the fast
path still covers manifest handling, config sync, excludes, dry-run, fish,
fisher and idempotency.

After `setup.sh` returns, `test/smoke.sh` asserts that fish installed and
registered, the expected configs landed, desktop configs did *not* land under
`--headless`, nothing under `~/.config` is root-owned, `--dry-run` changed
nothing, a second run still succeeds, and — most usefully — that
`fish -lic exit` starts with no errors. That last check is what catches a
config referencing a tool that is not installed.

macOS cannot be containerised; test it by running `./setup.sh --dry-run`.

---

## What you get

**Tools** — `atuin` (shell history search and sync), `bat`, `dust`, `eza`,
`fastfetch`, `fd`, `fzf`, `lazydocker`, `lazygit`, `neovim`, `ripgrep`,
`yazi`, `zellij`, `zoxide`, plus `uv` for Python.

**Configs** — fish, nvim (LazyVim), zellij, yazi, btop, git, atuin, and the
desktop set (kitty, ghostty, zed).

**Fish aliases** — `ls`→eza, `lg`→lazygit, `ld`→lazydocker, `ff`→fastfetch,
`nv`→nvim, `y`→yazi with directory tracking. Every one is guarded by
`command -q`, so a missing tool means a missing alias rather than an error on
every prompt.

### After installing

```bash
exec fish                     # start fish now
chsh -s "$(command -v fish)"  # make it your login shell
```

`setup.sh` writes `~/.config/git/config.local` with your git identity and the
right credential helper for the platform. It is not tracked — **check that the
name and email in it are correct.**

---

## Notes

Hyprland, Waybar, Walker and the Omarchy theming were removed; the repo no
longer depends on Omarchy being installed. To bring them back, restore
`config/<name>/` and add a `name:desktop,linux` entry to `CONFIGS`.

## Contributing

Issues and pull requests welcome. `test/run.sh all` should pass, and
`test/run.sh --lint` should be clean.

## License

MIT.

## 🤖 AI usage

Originally created without AI but now used as it makes fixing issues faster.

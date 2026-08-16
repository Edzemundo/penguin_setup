# shellcheck shell=bash
#
# lib/shell.sh -- fish installation, shell registration, plugin management via
# fisher, and the machine-local git identity file.
#
# Runs after configs are in place, because fisher reads the fish_plugins that
# the config step installs.
#
# Note this never runs chsh. Changing someone's login shell is a bigger
# decision than a setup script should make on its own, so the README tells you
# the command and leaves it to you.
#
# Globals read: OS, PM, DRY_RUN.  Entry point is setup_shell(); write_git_local
# is called separately by setup.sh.

FISHER_URL='https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish'

# Where the fish_plugins checksum stamp lives. Not in ~/.config, because it is
# derived state rather than configuration and must not be synced.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/penguin_setup"

# install_fish
# Installs fish from whichever package manager this host uses. Fatal on
# failure -- fish is the entire point of the setup.
install_fish() {
  if command -v fish >/dev/null 2>&1; then
    dim "fish already installed ($(fish --version 2>/dev/null))"
    return 0
  fi

  log "Installing fish"
  case "$PM" in
    brew)   run brew install fish ;;
    apt)    run sudo apt-get install -y -qq fish ;;
    dnf)    run sudo dnf install -y -q fish ;;
    pacman) run sudo pacman -S --needed --noconfirm fish ;;
  esac || die "fish install failed"
}

# register_shell
# Adds fish's path to /etc/shells, which chsh refuses to set a shell not
# listed in. One of the few places sudo is genuinely required.
#
# Non-fatal: an unwritable /etc/shells is worth a warning, but the rest of the
# setup is still useful without it -- you just cannot chsh until it is fixed.
register_shell() {
  local fish_bin
  fish_bin="$(command -v fish 2>/dev/null || true)"
  if [ -z "$fish_bin" ]; then
    $DRY_RUN && return 0
    warn "fish not found, skipping shell registration"
    return 0
  fi

  if [ -f /etc/shells ] && grep -qxF "$fish_bin" /etc/shells; then
    dim "$fish_bin already in /etc/shells"
    return 0
  fi

  log "Registering $fish_bin in /etc/shells"
  if $DRY_RUN; then
    dim "[dry-run] append $fish_bin to /etc/shells"
    return 0
  fi
  printf '%s\n' "$fish_bin" | sudo tee -a /etc/shells >/dev/null \
    || warn "could not write /etc/shells"
}

# Install fisher itself, then the plugins listed in fish_plugins.
#
# This used to run on every setup because pulling configs did `rm -rf
# ~/.config/fish`, destroying the installed plugins each time. Sync now
# excludes fisher's directories, so plugins survive and this only needs to run
# when the plugin list actually changes.
fisher_sync() {
  local plugins="$HOME/.config/fish/fish_plugins"
  local stamp="$STATE_DIR/fish_plugins.sha"
  local fish_bin
  fish_bin="$(command -v fish 2>/dev/null || true)"

  if [ -z "$fish_bin" ] || [ ! -f "$plugins" ]; then
    $DRY_RUN || warn "fish or fish_plugins missing, skipping fisher"
    return 0
  fi

  # Skip when the plugin list has not changed since the last successful run
  # AND fisher is genuinely present. The second half of that condition matters:
  # a stale stamp with fisher somehow gone would otherwise skip forever.
  local current
  current="$(_sha256 "$plugins")"
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$current" ] \
     && "$fish_bin" -c 'functions -q fisher' 2>/dev/null; then
    dim "fish plugins unchanged"
    return 0
  fi

  log "Installing fish plugins"
  if $DRY_RUN; then
    dim "[dry-run] fisher install < $plugins"
    return 0
  fi

  if ! "$fish_bin" -c 'functions -q fisher' 2>/dev/null; then
    local tmp
    tmp="$(mktemp)" || die "mktemp failed"
    curl -fsSL --retry 3 -o "$tmp" "$FISHER_URL" \
      || { rm -f "$tmp"; warn "fisher download failed"; return 0; }
    [ -s "$tmp" ] || { rm -f "$tmp"; warn "fisher download was empty"; return 0; }
    "$fish_bin" -c "source $tmp && fisher install jorgebucaran/fisher" \
      || warn "fisher bootstrap failed"
    rm -f "$tmp"
  fi

  if "$fish_bin" -c "fisher update < $plugins"; then
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$current" >"$stamp"
    ok "fish plugins installed"
  else
    warn "fisher plugin install failed"
  fi
}

# _sha256 <file>  ->  hex digest
# sha256sum on Linux, shasum on macOS, which ships no sha256sum.
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# write_git_local
# Writes ~/.config/git/config.local, which config/git/config includes.
#
# Keeps identity and the platform credential helper out of the repo, so the
# tracked git config is identical on every machine and no one's name and email
# get published. Never overwrites an existing file -- yours wins.
#
# The identity is inherited from any existing global git config, falling back
# to user@hostname, which is a placeholder worth correcting; setup.sh prints a
# reminder to check it.
write_git_local() {
  local target="$HOME/.config/git/config.local"
  [ -f "$target" ] && { dim "git config.local already present"; return 0; }

  local helper
  if [ "$OS" = macos ]; then
    helper=osxkeychain
  elif command -v git-credential-libsecret >/dev/null 2>&1; then
    helper=libsecret
  else
    helper=cache
  fi

  log "Writing git config.local"
  if $DRY_RUN; then
    dim "[dry-run] write $target (credential helper: $helper)"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  cat >"$target" <<EOF
# Local git settings for this machine. Not tracked by penguin_setup.
# Included from config/git/config.

[user]
	name = $(git config --global user.name 2>/dev/null || id -un)
	email = $(git config --global user.email 2>/dev/null || printf '%s@%s' "$(id -un)" "$(uname -n)")

[credential]
	helper = $helper
EOF
  ok "wrote $target -- check the identity in it is right"
}

# setup_shell
# Entry point. fisher_sync must come last: it needs both fish installed and
# fish_plugins already copied into ~/.config by the config step.
setup_shell() {
  install_fish
  register_shell
  fisher_sync
}

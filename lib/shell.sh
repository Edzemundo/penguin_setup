# shellcheck shell=bash
#
# Fish shell installation, registration, and plugin management via fisher.

FISHER_URL='https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish'

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/penguin_setup"

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

# Add fish to /etc/shells so chsh will accept it.
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

_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Write the git identity and platform credential helper that config/git/config
# includes. Kept out of the repo so the tracked config stays machine-neutral.
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
	email = $(git config --global user.email 2>/dev/null || printf '%s@%s' "$(id -un)" "$(hostname)")

[credential]
	helper = $helper
EOF
  ok "wrote $target -- check the identity in it is right"
}

setup_shell() {
  install_fish
  register_shell
  fisher_sync
}

# shellcheck shell=bash
#
# Installers for the things that do not come from a package manager:
# Homebrew, uv, yay, and the Xcode command line tools.
#
# Each one checks whether it is already present and returns quietly if so.

BREW_URL='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
UV_URL='https://astral.sh/uv/install.sh'

# Put brew on PATH for the rest of this process if it is installed anywhere
# we recognise. Safe to call before brew exists -- it just does nothing.
load_brew_env() {
  local prefix
  for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
    if [ -x "$prefix/bin/brew" ]; then
      # Some brew versions reference unset variables while printing shellenv.
      set +u
      eval "$("$prefix/bin/brew" shellenv)"
      set -u
      return 0
    fi
  done
  return 1
}

install_homebrew() {
  skipped brew && { dim "skipping Homebrew"; return 0; }

  if load_brew_env && command -v brew >/dev/null 2>&1; then
    dim "Homebrew already installed ($(brew --prefix))"
    return 0
  fi

  log "Installing Homebrew"
  # The installer calls sudo itself where it needs to.
  NONINTERACTIVE=1 fetch_and_run "$BREW_URL" bash || die "Homebrew install failed"

  load_brew_env || die "Homebrew installed but brew is not on PATH"
  ok "Homebrew installed at $(brew --prefix)"
}

install_uv() {
  skipped uv && { dim "skipping uv"; return 0; }

  if command -v uv >/dev/null 2>&1; then
    dim "uv already installed"
    return 0
  fi

  log "Installing uv"
  fetch_and_run "$UV_URL" sh || warn "uv install failed, continuing"
}

# Arch only. makepkg refuses to run as root, which is one more reason the
# whole script runs unprivileged.
install_yay() {
  [ "$PM" = pacman ] || return 0
  skipped aur && { dim "skipping yay"; return 0; }

  if command -v yay >/dev/null 2>&1; then
    dim "yay already installed"
    return 0
  fi

  log "Installing yay"
  if $DRY_RUN; then
    dim "[dry-run] build and install yay from the AUR"
    return 0
  fi

  local build
  build="$(mktemp -d)" || die "mktemp -d failed"
  # A fixed /tmp/yay path collides with itself on the second run.
  git clone --depth 1 https://aur.archlinux.org/yay.git "$build/yay" \
    || { rm -rf "$build"; warn "yay clone failed, continuing"; return 0; }
  ( cd "$build/yay" && makepkg -si --noconfirm ) \
    || warn "yay build failed, continuing"
  rm -rf "$build"
}

# macOS only. Cannot be automated past kicking off the GUI installer.
ensure_xcode_clt() {
  [ "$OS" = macos ] || return 0

  if xcode-select -p >/dev/null 2>&1; then
    dim "Xcode command line tools already installed"
    return 0
  fi

  log "Installing Xcode command line tools"
  run xcode-select --install || true
  die "Finish the Xcode command line tools installation, then run this script again."
}

bootstrap() {
  ensure_xcode_clt
  install_homebrew
  install_yay
  install_uv
}

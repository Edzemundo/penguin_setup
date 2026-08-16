# shellcheck shell=bash
#
# lib/bootstrap.sh -- installers for the things that do not come from a
# package manager: Homebrew, uv, yay, and the Xcode command line tools.
#
# These run before lib/packages.sh, because Homebrew is what provides most of
# the tools that follow. Each installer checks whether its target is already
# present and returns quietly if so, so the whole file is re-runnable.
#
# Everything here is fetched from the internet, so every download goes through
# fetch_and_run (verify, then execute) rather than piping curl into a shell.
#
# Globals read: OS, PM, DRY_RUN, SKIP.  Entry point is bootstrap() at the end.

BREW_URL='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
UV_URL='https://astral.sh/uv/install.sh'

# load_brew_env  ->  0 if brew was found and put on PATH, 1 otherwise
#
# Homebrew's prefix differs by platform: /opt/homebrew on Apple Silicon,
# /usr/local on Intel Macs, /home/linuxbrew/.linuxbrew for a system-wide Linux
# install, and ~/.linuxbrew for a single-user one. Probing all four keeps this
# one function correct everywhere.
#
# Safe to call before brew exists -- it simply finds nothing and returns 1.
# Called again after install_homebrew so the new brew is usable immediately,
# which is what removes the previous version's re-eval hack in setup.sh.
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

# install_homebrew
# Installs Homebrew if absent and leaves brew on PATH for the current process.
# Fatal on failure: most of the tool list depends on it.
#
# NONINTERACTIVE=1 stops the installer waiting for a keypress. It calls sudo
# itself where it needs to, which is why this works from an unprivileged user.
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

# install_uv
# uv, the Python package and project manager. Installed via its own script
# rather than brew so the version matches upstream's release channel.
# Non-fatal: Python tooling is peripheral to the rest of the setup.
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

# bootstrap
# Entry point. Order matters: the Xcode tools provide the compiler Homebrew
# needs on macOS, and Homebrew must exist before anything tries to use brew.
bootstrap() {
  ensure_xcode_clt
  install_homebrew
  install_yay
  install_uv
}

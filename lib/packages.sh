# shellcheck shell=bash
#
# Package installation. Every list lives in packages.conf; nothing here
# names a package.
#
# The pattern throughout: work out what is missing first, then install only
# that. Installing an already-present package is usually harmless but slow,
# and on pacman it triggers a full reinstall.

# Fail early on a typo'd array name rather than silently installing nothing.
check_manifest() {
  require_array BREW_PACKAGES
  require_array BREW_PACKAGES_LINUX
  require_array BREW_CASKS
  require_array APT_PACKAGES
  require_array DNF_PACKAGES
  require_array DNF_GROUPS
  require_array PACMAN_PACKAGES
  require_array PACMAN_DESKTOP_PACKAGES
  require_array CONFIGS
  require_array SYNC_EXCLUDES_GLOBAL
}

# Refresh package indexes. Soft failure: a flaky mirror should not abort the
# whole setup when the packages we need may already be cached.
update_indexes() {
  skipped upgrade && { dim "skipping index update"; return 0; }
  log "Refreshing package index"
  case "$PM" in
    apt)    run sudo apt-get update -qq            || warn "apt update failed, continuing" ;;
    dnf)    run sudo dnf -q -y makecache           || warn "dnf makecache failed, continuing" ;;
    pacman) run sudo pacman -Sy --noconfirm        || warn "pacman -Sy failed, continuing" ;;
    brew)   run brew update                        || warn "brew update failed, continuing" ;;
  esac
}

# ---------------------------------------------------------------------------
# Native package manager
# ---------------------------------------------------------------------------

# Print those of the given packages that are not installed.
_missing_native() {
  local pkg
  for pkg in "$@"; do
    case "$PM" in
      apt)
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$' \
          || printf '%s\n' "$pkg"
        ;;
      dnf)
        rpm -q "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
        ;;
      pacman)
        pacman -Qi "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
        ;;
    esac
  done
}

# install_native <package>...
install_native() {
  [ "$#" -gt 0 ] || return 0

  local missing
  missing="$(_missing_native "$@")"
  if [ -z "$missing" ]; then
    dim "all ${#} native packages already installed"
    return 0
  fi

  info "installing: $(echo "$missing" | tr '\n' ' ')"
  # shellcheck disable=SC2086  # word splitting is intended here
  case "$PM" in
    apt)    run sudo apt-get install -y -qq $missing ;;
    dnf)    run sudo dnf install -y -q $missing ;;
    # --needed matters: without it pacman reinstalls everything each run.
    pacman) run sudo pacman -S --needed --noconfirm $missing ;;
  esac || die "native package install failed"
}

install_native_groups() {
  [ "$#" -gt 0 ] || return 0
  [ "$PM" = dnf ] || return 0
  local group
  for group in "$@"; do
    run sudo dnf group install -y -q "$group" || warn "group install failed: $group"
  done
}

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

install_brew_packages() {
  skipped brew && { dim "skipping brew packages"; return 0; }
  command -v brew >/dev/null 2>&1 || { warn "brew not on PATH, skipping brew packages"; return 0; }

  local -a wanted
  wanted=( ${BREW_PACKAGES[@]+"${BREW_PACKAGES[@]}"} )
  if [ "$OS" = linux ]; then
    wanted=( ${wanted[@]+"${wanted[@]}"} ${BREW_PACKAGES_LINUX[@]+"${BREW_PACKAGES_LINUX[@]}"} )
  fi
  [ "${#wanted[@]}" -gt 0 ] || return 0

  # One `brew list` beats one `brew list <pkg>` per package -- each invocation
  # costs a Ruby startup.
  local installed pkg
  installed="$(brew list --formula -1 2>/dev/null || true)"

  local -a missing
  missing=()
  for pkg in "${wanted[@]}"; do
    printf '%s\n' "$installed" | grep -qxF "$pkg" || missing=( ${missing[@]+"${missing[@]}"} "$pkg" )
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    dim "all ${#wanted[@]} brew formulae already installed"
  else
    info "installing: ${missing[*]}"
    run brew install "${missing[@]}" || die "brew install failed"
  fi

  install_brew_casks
}

install_brew_casks() {
  [ "$OS" = macos ] || return 0
  $HEADLESS && return 0
  [ "${#BREW_CASKS[@]}" -gt 0 ] || return 0

  local installed cask
  installed="$(brew list --cask -1 2>/dev/null || true)"

  local -a missing
  missing=()
  for cask in "${BREW_CASKS[@]}"; do
    printf '%s\n' "$installed" | grep -qxF "$cask" || missing=( ${missing[@]+"${missing[@]}"} "$cask" )
  done

  [ "${#missing[@]}" -gt 0 ] || return 0
  info "installing casks: ${missing[*]}"
  run brew install --cask "${missing[@]}" || warn "cask install failed"
}

upgrade_brew_packages() {
  $DO_UPGRADE || return 0
  command -v brew >/dev/null 2>&1 || return 0
  log "Upgrading brew packages"
  run brew upgrade || warn "brew upgrade failed, continuing"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

install_packages() {
  log "Installing packages"

  case "$PM" in
    apt)
      install_native ${APT_PACKAGES[@]+"${APT_PACKAGES[@]}"}
      ;;
    dnf)
      install_native ${DNF_PACKAGES[@]+"${DNF_PACKAGES[@]}"}
      install_native_groups ${DNF_GROUPS[@]+"${DNF_GROUPS[@]}"}
      ;;
    pacman)
      install_native ${PACMAN_PACKAGES[@]+"${PACMAN_PACKAGES[@]}"}
      $HEADLESS || install_native ${PACMAN_DESKTOP_PACKAGES[@]+"${PACMAN_DESKTOP_PACKAGES[@]}"}
      ;;
    brew)
      : # macOS has no native manager; everything comes from brew below
      ;;
  esac

  install_brew_packages
  upgrade_brew_packages
}

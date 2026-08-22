# shellcheck shell=bash
#
# lib/packages.sh -- package installation.
#
# Every list lives in packages.conf; nothing in this file names a package.
# That is the whole point of the rewrite: adding a tool means editing one
# array, not hunting through six scripts.
#
# The pattern throughout: work out what is missing first, then install only
# that. Installing an already-present package is usually just slow, but on
# pacman without --needed it is a full reinstall, and it makes the output
# useless for seeing what a run actually did.
#
# Failure policy: refreshing an index is allowed to fail with a warning, since
# the packages may already be cached and a flaky mirror should not abort a
# setup. An actual install failing is fatal -- continuing would produce a
# half-configured machine that looks like it succeeded. The AUR is the one
# exception on the install side; see install_aur.
#
# Globals read: PM, OS, HEADLESS, DRY_RUN, DO_UPGRADE, AUR_HELPER, and the
#               packages.conf arrays. Entry point is install_packages at the
#               bottom.

# check_manifest
# Verifies every array packages.conf is supposed to define actually exists.
# Called once at startup so a typo fails immediately and by name, rather than
# silently expanding to nothing and installing an empty list.
check_manifest() {
  require_array BREW_PACKAGES
  require_array BREW_PACKAGES_LINUX
  require_array BREW_CASKS
  require_array APT_PACKAGES
  require_array DNF_PACKAGES
  require_array DNF_GROUPS
  require_array PACMAN_PACKAGES
  require_array PACMAN_DESKTOP_PACKAGES
  require_array AUR_PACKAGES
  require_array CONFIGS
  require_array SYNC_EXCLUDES_GLOBAL
}

# Refresh package indexes. This is a prerequisite for installing, not part of
# upgrading -- skipping it leaves apt unable to locate any package at all on a
# slim image. Gate it on its own token, not on --skip=upgrade.
#
# Soft failure: a flaky mirror should not abort a setup whose packages may
# already be cached.
#
# pacman is the exception to "refreshing is not upgrading": -Sy followed by an
# -S install is a partial upgrade, which Arch does not support and which a
# fresh install -- whose ISO packages lag the mirrors by weeks -- is the most
# likely of all to break on. So the pacman refresh is a full -Syu, and a setup
# run on Arch or CachyOS upgrades the system whether --upgrade was given or
# not. That is a real difference in what this step does, so it is called out in
# the README's Arch and CachyOS notes as well as here. --skip=index opts out.
update_indexes() {
  skipped index && { dim "skipping index refresh"; return 0; }
  log "Refreshing package index"
  case "$PM" in
    apt)    run sudo apt-get update -qq      || warn "apt update failed, continuing" ;;
    dnf)    run sudo dnf -q -y makecache     || warn "dnf makecache failed, continuing" ;;
    pacman) run sudo pacman -Syu --noconfirm || warn "pacman -Syu failed, continuing" ;;
    brew)
      skipped brew && return 0
      run brew update || warn "brew update failed, continuing"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Native package manager
# ---------------------------------------------------------------------------

# _missing_native <package>...  ->  the subset that is not installed, one per line
#
# Each manager needs its own query, and each is chosen to be quiet and exact:
#   apt     dpkg-query, matched against the literal "install ok installed"
#           status, because a removed-but-not-purged package still has a record
#   dnf     rpm -q
#   pacman  pacman -Qi, which answers for AUR packages too -- once built they
#           are ordinary entries in the local database, so install_aur reuses
#           this rather than asking the helper
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
# Installs any of the named packages that are missing, via the detected PM.
# Fatal on failure.
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

# install_native_groups <group>...
# dnf package groups (e.g. development-tools). A no-op on every other manager,
# because only dnf has the concept -- apt and pacman use metapackages, which
# go in the ordinary package arrays instead.
install_native_groups() {
  [ "$#" -gt 0 ] || return 0
  [ "$PM" = dnf ] || return 0
  local group
  for group in "$@"; do
    run sudo dnf group install -y -q "$group" || warn "group install failed: $group"
  done
}

# install_aur <package>...
# Builds AUR packages with whichever helper install_aur_helper found. A no-op
# off pacman, and a no-op with a warning-free skip when there is no helper --
# --skip=aur, or a build that did not work out.
#
# Non-fatal where install_native is fatal: an AUR PKGBUILD is third-party
# source built on this machine and can fail for reasons entirely upstream of
# this repo. A broken AUR package should not take down a whole setup the way a
# missing build dependency should.
install_aur() {
  [ "$#" -gt 0 ] || return 0
  [ "$PM" = pacman ] || return 0
  if [ -z "${AUR_HELPER:-}" ]; then
    dim "no AUR helper, skipping ${#} AUR package(s)"
    return 0
  fi

  local missing
  missing="$(_missing_native "$@")"
  if [ -z "$missing" ]; then
    dim "all ${#} AUR packages already installed"
    return 0
  fi

  # paru and yay share pacman's -S interface, so one command line covers both.
  local -a args
  args=( -S --needed --noconfirm )
  # paru additionally opens a PKGBUILD diff for every new package, which
  # --noconfirm does not suppress; unattended, that waits on a pager forever.
  if [ "$AUR_HELPER" = paru ]; then
    args=( "${args[@]}" --skipreview )
  fi

  info "installing from AUR: $(echo "$missing" | tr '\n' ' ')"
  # shellcheck disable=SC2086  # word splitting is intended here
  run "$AUR_HELPER" "${args[@]}" $missing || warn "AUR install failed, continuing"
}

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

# install_brew_packages
# Installs BREW_PACKAGES, plus BREW_PACKAGES_LINUX on Linux, then any casks.
#
# Homebrew is the cross-platform half of the story: the same formulae on macOS
# and Linux means the same tool versions everywhere, which is why the native
# lists stay minimal.
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

# install_brew_casks
# GUI applications, so macOS only and never under --headless.
# Non-fatal: a cask can fail for reasons (an existing app bundle, a Gatekeeper
# prompt) that should not take down a whole setup run.
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

# upgrade_brew_packages
# Opt-in behind --upgrade. The previous version ran brew upgrade on every
# setup, which is slow and can pull unrelated software forward at an
# inconvenient moment; installing a machine and upgrading everything on it are
# different intentions.
upgrade_brew_packages() {
  $DO_UPGRADE || return 0
  command -v brew >/dev/null 2>&1 || return 0
  log "Upgrading brew packages"
  run brew upgrade || warn "brew upgrade failed, continuing"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

# install_packages
# Entry point: native packages for the detected manager, then Homebrew.
# On macOS there is no native step -- PM is brew and everything comes from the
# Homebrew pass below.
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
      install_aur ${AUR_PACKAGES[@]+"${AUR_PACKAGES[@]}"}
      ;;
    brew)
      : # macOS has no native manager; everything comes from brew below
      ;;
  esac

  install_brew_packages
  upgrade_brew_packages
}

#!/usr/bin/env bash
#
# penguin_setup -- install and configure a development environment.
#
# Usage:
#   ./setup.sh [options]
#
# Options:
#   --headless        skip desktop application configs and packages
#   --dry-run         show what would happen, change nothing
#   --skip=a,b,c      skip steps: brew, aur, uv, upgrade, index
#   --upgrade         also upgrade already-installed brew packages
#   --yes             do not prompt
#   -h, --help        this message
#
# Everything installed or synced is listed in packages.conf.
#
# ---------------------------------------------------------------------------
# Structure
#
#   packages.conf      what to install and sync -- the only file naming a
#                      package or a config directory
#   lib/common.sh      output, system detection, mutating primitives
#   lib/bootstrap.sh   Homebrew, uv, AUR helper, Xcode CLT
#   lib/packages.sh    package installation per manager
#   lib/config.sh      config directory sync (shared with sync.sh)
#   lib/shell.sh       fish, fisher, git config.local
#
# The lib/ files are sourced rather than executed, so environment changes --
# most importantly Homebrew landing on PATH -- carry across steps.
#
# Run order is fixed by dependency: bootstrap gives us brew, brew gives us the
# tools, configs need rsync from the package step, and fisher needs both fish
# and the fish_plugins that the config step installs.
#
# Safe to re-run. Every step checks current state first, so a second run is
# close to a no-op and is exercised as a test assertion.
# ---------------------------------------------------------------------------

set -euo pipefail

# Resolve the repo root from this script's location, so it works from any
# working directory (the curl one-liner runs it from $HOME).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

# Defaults, set before sourcing lib/ because the helpers read them.
HEADLESS=false
DRY_RUN=false
ASSUME_YES=false
DO_UPGRADE=false
SKIP=''
ONLY=''                              # unused here; lib/config.sh expects it
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"   # one backup directory per invocation
TOTAL_CHANGED=0
TOTAL_DELETED=0

# Print the comment block at the top of this file as the help text, so usage
# and documentation cannot drift apart.
usage() { sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --headless)  HEADLESS=true ;;
    --dry-run)   DRY_RUN=true ;;
    --yes|-y)    ASSUME_YES=true ;;
    --upgrade)   DO_UPGRADE=true ;;
    --skip=*)    SKIP="${1#*=}" ;;
    --skip)      shift; SKIP="${1:-}" ;;
    -h|--help)   usage; exit 0 ;;
    *)           printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=lib/common.sh
. "$REPO/lib/common.sh"
# shellcheck source=packages.conf
. "$REPO/packages.conf"
# shellcheck source=lib/bootstrap.sh
. "$REPO/lib/bootstrap.sh"
# shellcheck source=lib/packages.sh
. "$REPO/lib/packages.sh"
# shellcheck source=lib/config.sh
. "$REPO/lib/config.sh"
# shellcheck source=lib/shell.sh
. "$REPO/lib/shell.sh"

require_not_root
check_manifest
detect_system

# install_configs
# Copies every applicable config directory from the repo into ~/.config.
# Identical to `sync.sh pull`, including the backups, and shares its code.
install_configs() {
  # Probed here rather than at startup: rsync is one of the packages we
  # install, so on a fresh machine it does not exist until the step above.
  probe_rsync

  log "Installing configs"
  local name
  # A here-document, not `applicable_configs | while ...`: a pipeline would
  # run the loop in a subshell and the TOTAL_* counters would not survive it.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    syncable "$name" pull && sync_dir "$name" pull
  done <<EOF
$(applicable_configs)
EOF
  $DRY_RUN || prune_backups
}

main() {
  local profile
  profile="$($HEADLESS && printf headless || printf desktop)"

  printf '\n'
  log "penguin_setup"
  info "system:   $DISTRO / $PM"
  info "profile:  $profile"
  [ -n "$SKIP" ] && info "skipping: $SKIP"
  $DRY_RUN && info "mode:     dry run, nothing will change"
  printf '\n'

  update_indexes
  bootstrap
  # Homebrew may have just been installed; get it onto PATH for what follows.
  # `|| true` because a --skip=brew run legitimately has no brew to find.
  load_brew_env || true
  install_packages
  install_configs
  setup_shell        # fisher needs the fish_plugins that install_configs put in place
  write_git_local

  printf '\n'
  if $DRY_RUN; then
    ok "Dry run complete -- re-run without --dry-run to apply"
    return 0
  fi

  ok "Setup complete"
  info "Start fish with:  exec fish"
  info "Make it default:  chsh -s $(command -v fish 2>/dev/null || printf '\$(command -v fish)')"
  printf '\n'
}

main

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
#   --skip=a,b,c      skip steps: brew, aur, uv, upgrade
#   --upgrade         also upgrade already-installed brew packages
#   --yes             do not prompt
#   -h, --help        this message
#
# Everything installed or synced is listed in packages.conf.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

# Defaults, set before sourcing lib/ because the helpers read them.
HEADLESS=false
DRY_RUN=false
ASSUME_YES=false
DO_UPGRADE=false
SKIP=''
ONLY=''
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
TOTAL_CHANGED=0
TOTAL_DELETED=0

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
probe_rsync

install_configs() {
  log "Installing configs"
  local name
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
  info "system:   $OS / $PM"
  info "profile:  $profile"
  [ -n "$SKIP" ] && info "skipping: $SKIP"
  $DRY_RUN && info "mode:     dry run, nothing will change"
  printf '\n'

  update_indexes
  bootstrap
  # Homebrew may have just been installed; get it onto PATH for what follows.
  load_brew_env || true
  install_packages
  install_configs
  setup_shell
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

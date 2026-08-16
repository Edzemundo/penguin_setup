#!/usr/bin/env bash
#
# penguin_setup -- move config between this machine and the repo.
#
# Usage:
#   ./sync.sh pull [options]     repo      -> ~/.config
#   ./sync.sh push [options]     ~/.config -> repo
#
# Options:
#   --headless       only the non-desktop configs
#   --dry-run        show what would change, change nothing
#   --only <name>    just one config directory
#   --force          skip the confirmation on large deletions
#   --yes            do not prompt
#   -h, --help       this message
#
# pull keeps a copy of anything it replaces under
# ~/.local/state/penguin_setup/backups/. push refuses to run unless config/ is
# clean in git, so `git checkout -- config/` is always an undo. Neither one
# commits anything.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

HEADLESS=false
DRY_RUN=false
ASSUME_YES=false
FORCE=false
ONLY=''
MODE=''
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
TOTAL_CHANGED=0
TOTAL_DELETED=0

# How many deletions in one run before we stop and ask.
DELETE_THRESHOLD=10

usage() { sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    pull|push)   MODE="$1" ;;
    --headless)  HEADLESS=true ;;
    --dry-run)   DRY_RUN=true ;;
    --force)     FORCE=true ;;
    --yes|-y)    ASSUME_YES=true ;;
    --only)      shift; ONLY="${1:-}" ;;
    --only=*)    ONLY="${1#*=}" ;;
    -h|--help)   usage; exit 0 ;;
    *)           printf 'unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=lib/common.sh
. "$REPO/lib/common.sh"
# shellcheck source=packages.conf
. "$REPO/packages.conf"
# shellcheck source=lib/config.sh
. "$REPO/lib/config.sh"

[ -n "$MODE" ] || { printf 'specify pull or push\n\n' >&2; usage >&2; exit 2; }

require_not_root
detect_system
probe_rsync

# Read the applicable config names into a list once, so we can count them
# before doing anything.
NAMES="$(applicable_configs)"
[ -n "$NAMES" ] || die "no configs match (--only '$ONLY'?)"

if [ -n "$ONLY" ]; then
  printf '%s\n' "$NAMES" | grep -qxF "$ONLY" \
    || die "'$ONLY' is not a config that applies here -- check CONFIGS in packages.conf"
fi

# ---------------------------------------------------------------------------
# push guards
# ---------------------------------------------------------------------------

# Require a clean config/ in git before overwriting it from the device. This
# is what makes the operation reversible: whatever push writes can be undone
# with `git checkout -- config/`.
require_clean_repo() {
  git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 \
    || die "not a git repository -- push needs git as its undo mechanism"

  # Untracked files matter as much as modified ones: git checkout cannot
  # bring back a file it never knew about, so they must be dealt with too.
  local untracked
  untracked="$(git -C "$REPO" ls-files --others --exclude-standard -- config/)"

  if ! git -C "$REPO" diff --quiet -- config/ \
     || ! git -C "$REPO" diff --cached --quiet -- config/ \
     || [ -n "$untracked" ]; then
    printf '\n'
    git -C "$REPO" status --short -- config/ >&2
    printf '\n'
    die "config/ has uncommitted changes -- commit or stash them first, so this push can be undone"
  fi
}

# Preview the whole push and stop if it would delete a surprising amount.
check_deletions() {
  local name total=0 n
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    syncable "$name" push || continue
    n="$(count_deletions "$name" push)"
    total=$((total + n))
  done <<EOF
$NAMES
EOF

  [ "$total" -gt 0 ] || return 0
  info "this push would delete $total file(s) from the repo"

  if [ "$total" -ge "$DELETE_THRESHOLD" ] && ! $FORCE; then
    confirm "Delete $total file(s) from the repo?" \
      || die "aborted -- re-run with --force to proceed"
  fi
}

# ---------------------------------------------------------------------------

main() {
  local count
  count="$(printf '%s\n' "$NAMES" | grep -c . || true)"

  printf '\n'
  log "penguin_setup sync: $MODE"
  if [ "$MODE" = pull ]; then
    info "repo/config  ->  ~/.config"
  else
    info "~/.config    ->  repo/config"
  fi
  info "configs:  $count$([ -n "$ONLY" ] && printf ' (--only %s)' "$ONLY")"
  $DRY_RUN && info "mode:     dry run, nothing will change"
  printf '\n'

  if [ "$MODE" = push ] && ! $DRY_RUN; then
    require_clean_repo
    check_deletions
  fi

  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    syncable "$name" "$MODE" && sync_dir "$name" "$MODE"
  done <<EOF
$NAMES
EOF

  printf '\n'
  if $DRY_RUN; then
    ok "Dry run: $TOTAL_CHANGED would change, $TOTAL_DELETED would be deleted"
    return 0
  fi

  ok "$TOTAL_CHANGED changed, $TOTAL_DELETED deleted"

  if [ "$MODE" = pull ]; then
    prune_backups
    if [ "$TOTAL_CHANGED" -gt 0 ] || [ "$TOTAL_DELETED" -gt 0 ]; then
      info "replaced files: $(backup_root)"
      info "restart your shell to pick up changes:  exec fish"
    fi
  else
    printf '\n'
    git -C "$REPO" status --short -- config/
    printf '\n'
    info "review with 'git diff -- config/', then commit when you are happy"
  fi
  printf '\n'
}

main

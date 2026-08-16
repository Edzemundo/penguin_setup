# shellcheck shell=bash
# shellcheck disable=SC2154  # colour vars are defined in lib/common.sh
#
# lib/config.sh -- moving config directories between the repo and ~/.config,
# in both directions, without losing anything.
#
# This is the module where the safety properties live, so the two invariants
# worth keeping in mind while editing:
#
#   1. Excluded paths are protected on BOTH ends. rsync will not delete a file
#      it was told to exclude, which is the only reason --delete is safe here.
#      Never add --delete-excluded: it inverts this and would destroy exactly
#      the machine-local state the excludes exist to protect (fisher plugins,
#      atuin's history database, nvim's lockfile).
#   2. Nothing is deleted without a way back. pull writes replaced files to a
#      timestamped backup directory; push refuses to run unless config/ is
#      clean in git, so `git checkout -- config/` is always the undo.
#
# Globals read: REPO, HOME, OS, HEADLESS, ONLY, DRY_RUN, RUN_STAMP, CONFIGS,
#               SYNC_EXCLUDES_GLOBAL, EXCLUDES_<name>
# Globals written: TOTAL_CHANGED, TOTAL_DELETED, RSYNC_CHMOD_OK

# config_name <entry>   ->  "kitty" from "kitty:desktop"
config_name() { printf '%s' "${1%%:*}"; }

# config_applies <entry>  ->  0 if this host should have it, 1 otherwise
#
# Entries are "name" or "name:tag,tag". All tags must match. An unknown tag
# warns rather than failing, so a newer packages.conf degrades to installing
# too much rather than refusing to run.
#
# Reads HEADLESS and OS from the caller.
config_applies() {
  local tags="${1#*:}"
  [ "$tags" = "$1" ] && return 0        # no colon, so no tags: always applies

  local tag
  local IFS=,
  for tag in $tags; do
    case "$tag" in
      desktop) $HEADLESS && return 1 ;;
      linux)   [ "$OS" = linux ] || return 1 ;;
      macos)   [ "$OS" = macos ] || return 1 ;;
      *)       warn "unknown tag '$tag' on config entry '$1'" ;;
    esac
  done
  return 0
}

# excludes_for <name>  ->  one rsync filter pattern per line on stdout
#
# Global patterns first, then any EXCLUDES_<name> array. Two bash 3.2 details:
#
#   ref="EXCLUDES_$1[@]" plus ${!ref} is indirect expansion of an array, which
#   is how you look up a variable by computed name without declare -A.
#   ${!ref+"${!ref}"} yields nothing at all when no such array exists, instead
#   of erroring under set -u -- most configs have no per-directory excludes.
#
# Emitted on stdout and piped to rsync's --exclude-from=- rather than built
# into an argv array, which sidesteps empty-array expansion entirely.
excludes_for() {
  local pattern ref="EXCLUDES_$1[@]"
  for pattern in ${SYNC_EXCLUDES_GLOBAL[@]+"${SYNC_EXCLUDES_GLOBAL[@]}"}; do
    printf '%s\n' "$pattern"
  done
  for pattern in ${!ref+"${!ref}"}; do
    printf '%s\n' "$pattern"
  done
}

# applicable_configs  ->  the config names for this host, one per line
#
# Filters CONFIGS by tag and by --only. Callers read it with a here-document
# rather than a pipe, so the loop body runs in the current shell and can
# update the TOTAL_* counters.
applicable_configs() {
  local entry name
  for entry in "${CONFIGS[@]}"; do
    name="$(config_name "$entry")"
    if [ -n "$ONLY" ] && [ "$name" != "$ONLY" ]; then
      continue
    fi
    config_applies "$entry" && printf '%s\n' "$name"
  done
  # Explicit: without this the function returns the status of the last
  # iteration, so a trailing entry that does not apply (zed:desktop under
  # --headless) would make `x="$(applicable_configs)"` fail under set -e.
  return 0
}

# ---------------------------------------------------------------------------
# Directory sync
# ---------------------------------------------------------------------------
#
# Both directions use --delete so that deleting a file actually propagates.
# That is safe here only because excluded paths are protected on both ends:
# rsync will not remove something it was told to exclude. Never add
# --delete-excluded -- that is exactly what would destroy machine-local state
# such as fisher's installed plugins or atuin's history database.

# macOS ships openrsync, which lists --chmod in its help text but rejects it
# at runtime, so the version string cannot be trusted. Probe once with a real
# transfer. Without it we simply do not normalise modes -- a cosmetic loss.
RSYNC_CHMOD_OK=false
probe_rsync() {
  command -v rsync >/dev/null 2>&1 || die "rsync is required but not installed"
  local d
  d="$(mktemp -d)" || return 0
  mkdir -p "$d/a" "$d/b"
  : >"$d/a/probe"
  if rsync -rlt --chmod=F644,D755 "$d/a/" "$d/b/" >/dev/null 2>&1; then
    RSYNC_CHMOD_OK=true
  fi
  rm -rf "$d"
}

# backup_root  ->  absolute path for this run's pull backups
#
# One directory per invocation (RUN_STAMP is set once at startup), so a single
# pull's replaced files stay together. rsync creates it lazily, which is why a
# no-op pull leaves no empty directory behind.
backup_root() {
  printf '%s/penguin_setup/backups/%s' \
    "${XDG_STATE_HOME:-$HOME/.local/state}" "$RUN_STAMP"
}

# syncable <name> <mode>  ->  0 if there is something worth syncing
#
# Warns and returns 1 rather than dying: one missing config should not abort
# the other nine. The empty-directory check on push is the important one --
# see the comment inline.
syncable() {
  local name="$1" mode="$2"
  case "$mode" in
    pull)
      if [ ! -d "$REPO/config/$name" ]; then
        warn "$name: not in the repo, skipping"
        return 1
      fi
      ;;
    push)
      if [ ! -d "$HOME/.config/$name" ]; then
        warn "$name: not present on this device, skipping"
        return 1
      fi
      # An empty directory almost always means the config was removed locally.
      # Pushing it would delete the repo copy, which is rarely intended.
      if [ -z "$(find "$HOME/.config/$name" -type f -print -quit 2>/dev/null)" ]; then
        warn "$name: empty on this device, skipping"
        return 1
      fi
      ;;
  esac
  return 0
}

# rsync_dir <name> <pull|push> <dry:true|false>
# Writes rsync's itemised output to stdout. The single place rsync is invoked.
#
# The flag choices differ by direction and both are deliberate:
#
#   pull  -rlpt  keep permissions, since the repo's modes are the intended
#                ones on disk. No -og: writing owner/group is what forced the
#                old code to chown -R afterwards.
#   push  -rlt --no-perms [--chmod]  drop permissions instead, because git
#                records only the executable bit. Normalising modes stops a
#                local umask showing up as a permission-only diff.
#
# Never -a. It expands to -rlptgoD, quietly pulling in the -og this avoids.
rsync_dir() {
  local name="$1" mode="$2" dry="$3"
  local src dst
  local -a opts

  if [ "$mode" = pull ]; then
    src="$REPO/config/$name/"
    dst="$HOME/.config/$name/"
    # --backup-dir must be absolute, or rsync resolves it relative to the
    # destination and scatters copies inside ~/.config/<name>/.
    opts=( -rlpt --delete --backup --backup-dir="$(backup_root)/$name" )
    [ "$dry" = true ] || mkdir -p "$dst"
  else
    src="$HOME/.config/$name/"
    dst="$REPO/config/$name/"
    # -rlt rather than -a: -a implies -og, writing owner and group that git
    # does not record anyway. --chmod, where supported, normalises modes so a
    # local umask quirk does not surface as a permission-only diff.
    opts=( -rlt --delete --no-perms )
    # shellcheck disable=SC2054  # the comma belongs to rsync's --chmod syntax
    $RSYNC_CHMOD_OK && opts=( "${opts[@]}" --chmod=F644,D755 )
    [ "$dry" = true ] || mkdir -p "$dst"
  fi

  [ "$dry" = true ] && opts=( "${opts[@]}" --dry-run )

  excludes_for "$name" \
    | rsync "${opts[@]}" --exclude-from=- --itemize-changes "$src" "$dst"
}

# count_deletions <name> <mode>  ->  how many files a real run would remove
#
# Always a dry run, so it is safe to call before deciding whether to proceed.
# `|| true` because grep -c exits 1 when the count is zero, which under set -e
# would abort the very check meant to prevent surprises.
count_deletions() {
  rsync_dir "$1" "$2" true | grep -c '^\*deleting' || true
}

# sync_dir <name> <pull|push>
# Runs one directory's transfer and reports it.
# Adds to TOTAL_CHANGED / TOTAL_DELETED.
sync_dir() {
  local name="$1" mode="$2" out
  out="$(mktemp)" || die "mktemp failed"

  if ! rsync_dir "$name" "$mode" "$DRY_RUN" >"$out"; then
    rm -f "$out"
    die "rsync failed for $name"
  fi

  # Redirect rather than pipe: a pipeline would run report_changes in a
  # subshell and the totals would be lost.
  report_changes "$name" <"$out"
  rm -f "$out"
}

# report_changes <name>   (itemised rsync output on stdin)
# Summarises one directory, listing deletions in full since those are the
# changes actually worth reading. Updates TOTAL_CHANGED and TOTAL_DELETED.
#
# rsync's itemised format is an 11-character code then the path:
#   *deleting  path     removed from the destination
#   >f.st....  path     transferred (> received, < sent, c created, h hardlink)
# Matching on the first character is enough to tell them apart.
#
# Must be fed by redirect, never a pipe -- see sync_dir.
report_changes() {
  local name="$1" line file changed=0 deleted=0
  while IFS= read -r line; do
    case "$line" in
      '*deleting'*)
        deleted=$((deleted + 1))
        # GNU rsync pads this with three spaces, openrsync with one, so strip
        # the keyword and then any leading whitespace.
        file="${line#\*deleting}"
        while [ "${file# }" != "$file" ]; do file="${file# }"; done
        printf '      %s- %s%s\n' "$_c_yellow" "$file" "$_c_off"
        ;;
      [\<\>ch]*)
        changed=$((changed + 1))
        dim "  ${line##* }"
        ;;
    esac
  done

  if [ "$changed" -eq 0 ] && [ "$deleted" -eq 0 ]; then
    dim "$name: unchanged"
  else
    ok "$name: $changed changed, $deleted deleted"
  fi
  TOTAL_CHANGED=$((TOTAL_CHANGED + changed))
  TOTAL_DELETED=$((TOTAL_DELETED + deleted))
}

# prune_backups
# Keeps the five most recent backup runs and removes older ones, so the state
# directory does not grow without bound.
#
# ls -1dt sorts newest first; tail -n +6 selects everything past the fifth.
prune_backups() {
  local root keep=5 old
  root="$(dirname "$(backup_root)")"
  [ -d "$root" ] || return 0
  # Sanity-check the path before deleting anything beneath it: this function
  # runs rm -rf in a loop, and a malformed XDG_STATE_HOME must not turn that
  # into a recursive delete of somewhere unexpected.
  case "$root" in
    */penguin_setup/backups) ;;
    *) warn "refusing to prune unexpected backup path: $root"; return 0 ;;
  esac
  ls -1dt "$root"/*/ 2>/dev/null | tail -n +$((keep + 1)) | while IFS= read -r old; do
    rm -rf "$old"
  done
}

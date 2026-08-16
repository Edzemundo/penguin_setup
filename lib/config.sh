# shellcheck shell=bash
#
# Moving config directories between the repo and ~/.config, in both
# directions, without losing anything.

# config_name <entry>   ->  "kitty" from "kitty:desktop"
config_name() { printf '%s' "${1%%:*}"; }

# config_applies <entry>  ->  0 if this host should have it
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

# excludes_for <name>  ->  one rsync filter pattern per line
# Global patterns first, then any EXCLUDES_<name> array. Emitted on stdout and
# fed to rsync via --exclude-from=- so an empty list needs no special casing.
excludes_for() {
  local pattern ref="EXCLUDES_$1[@]"
  for pattern in ${SYNC_EXCLUDES_GLOBAL[@]+"${SYNC_EXCLUDES_GLOBAL[@]}"}; do
    printf '%s\n' "$pattern"
  done
  for pattern in ${!ref+"${!ref}"}; do
    printf '%s\n' "$pattern"
  done
}

# The config names that apply to this host, one per line.
# Honours --only by matching the bare name.
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

# Where replaced files go on pull. Created lazily, so a no-op pull leaves
# nothing behind.
backup_root() {
  printf '%s/penguin_setup/backups/%s' \
    "${XDG_STATE_HOME:-$HOME/.local/state}" "$RUN_STAMP"
}

# syncable <name> <mode>  ->  0 if there is something to sync
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
# Writes rsync's itemised output to stdout.
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
    $RSYNC_CHMOD_OK && opts=( "${opts[@]}" --chmod=F644,D755 )
    [ "$dry" = true ] || mkdir -p "$dst"
  fi

  [ "$dry" = true ] && opts=( "${opts[@]}" --dry-run )

  excludes_for "$name" \
    | rsync "${opts[@]}" --exclude-from=- --itemize-changes "$src" "$dst"
}

# count_deletions <name> <mode>  ->  prints how many files a real run would remove
count_deletions() {
  rsync_dir "$1" "$2" true | grep -c '^\*deleting' || true
}

# sync_dir <name> <pull|push>
# Runs the transfer and reports it. Adds to TOTAL_CHANGED / TOTAL_DELETED.
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

# Summarise one directory's itemised output, listing deletions in full since
# those are the changes actually worth reading.
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

# Keep the most recent backup runs, drop older ones.
prune_backups() {
  local root keep=5 old
  root="$(dirname "$(backup_root)")"
  [ -d "$root" ] || return 0
  # Sanity-check the path before deleting anything beneath it.
  case "$root" in
    */penguin_setup/backups) ;;
    *) warn "refusing to prune unexpected backup path: $root"; return 0 ;;
  esac
  ls -1dt "$root"/*/ 2>/dev/null | tail -n +$((keep + 1)) | while IFS= read -r old; do
    rm -rf "$old"
  done
}

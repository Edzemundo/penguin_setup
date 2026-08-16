# shellcheck shell=bash
#
# Shared helpers: output, system detection, and the small set of primitives
# that actually change the machine.
#
# Targets bash 3.2 -- that is what /bin/bash is on macOS, and it runs before
# Homebrew exists. So no associative arrays, no mapfile, no ${var,,}.

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_green=$'\033[32m'
  _c_blue=$'\033[34m'; _c_dim=$'\033[2m'; _c_off=$'\033[0m'
else
  _c_red=''; _c_yellow=''; _c_green=''; _c_blue=''; _c_dim=''; _c_off=''
fi

log()   { printf '%s==>%s %s\n' "$_c_blue" "$_c_off" "$*"; }
info()  { printf '    %s\n' "$*"; }
dim()   { printf '%s    %s%s\n' "$_c_dim" "$*" "$_c_off"; }
ok()    { printf '%s  ✓%s %s\n' "$_c_green" "$_c_off" "$*"; }
warn()  { printf '%s  ! %s%s\n' "$_c_yellow" "$*" "$_c_off" >&2; }
die()   { printf '%serror:%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }

# Ask for confirmation. Auto-yes under --yes or when stdin is not a terminal.
confirm() {
  $ASSUME_YES && return 0
  [ -t 0 ] || return 0
  printf '%s [y/N] ' "$1"
  local reply=''
  read -r reply
  case "$reply" in [yY] | [yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# Run a command, or just print it under --dry-run.
# Only works for plain commands -- no pipes or redirects.
run() {
  if $DRY_RUN; then
    printf '%s    [dry-run] %s%s\n' "$_c_dim" "$*" "$_c_off"
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# System detection
# ---------------------------------------------------------------------------

# Sets OS (macos|linux) and PM (brew|apt|dnf|pacman). Called once.
detect_system() {
  case "${OSTYPE:-}" in
    darwin*)
      OS=macos
      PM=brew
      ;;
    *)
      OS=linux
      if   command -v apt-get >/dev/null 2>&1; then PM=apt
      elif command -v dnf     >/dev/null 2>&1; then PM=dnf
      elif command -v pacman  >/dev/null 2>&1; then PM=pacman
      else die "no supported package manager found (need apt, dnf or pacman)"
      fi
      ;;
  esac
}

# Refuse to run as root. Everything here belongs to one user; the few commands
# that genuinely need elevation call sudo themselves. Running the whole script
# as root writes root-owned files into a user's ~/.config.
require_not_root() {
  [ "$(id -u)" -ne 0 ] || die "do not run as root -- run as your normal user; sudo is called only where needed

  If you used the curl one-liner with sudo, re-run it without."
}

# True when a step was named in --skip=a,b,c
skipped() {
  case ",$SKIP," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Mutating primitives -- each safe to run repeatedly
# ---------------------------------------------------------------------------

_MARKER='# >>> penguin_setup >>>'

# append_line_once <file> <line>
# Tags the block so it can be found and removed later.
append_line_once() {
  local file="$1" line="$2"
  if [ -f "$file" ] && grep -qxF "$line" "$file"; then
    return 0
  fi
  if $DRY_RUN; then
    dim "[dry-run] append to $file: $line"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  {
    printf '\n%s\n' "$_MARKER"
    printf '%s\n' "$line"
    printf '# <<< penguin_setup <<<\n'
  } >>"$file"
  ok "updated $file"
}

# symlink <target> <linkname>
# -f -n so it also replaces an existing or dangling symlink. Plain [ -e ] is
# false for a dangling link, which is how the old code silently failed.
symlink() {
  local target="$1" link="$2"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    return 0
  fi
  run ln -sfn "$target" "$link"
}

# fetch_and_run <url> <interpreter>
# Downloads to a temp file first. Piping curl straight into a shell means an
# HTTP error page gets executed; -f plus a size check prevents that.
fetch_and_run() {
  local url="$1" interp="$2" tmp
  if $DRY_RUN; then
    dim "[dry-run] fetch $url | $interp"
    return 0
  fi
  tmp="$(mktemp)" || die "mktemp failed"
  # shellcheck disable=SC2064  # expand tmp now, not at trap time
  trap "rm -f '$tmp'" RETURN
  curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url" \
    || die "download failed: $url"
  [ -s "$tmp" ] || die "downloaded an empty file: $url"
  "$interp" "$tmp"
}

# Guard against a typo'd array name in packages.conf silently reading as empty.
# declare -p, not ${x+set}: the latter reports a legitimately empty array
# (BREW_CASKS=()) as missing, because it tests element 0 rather than the name.
require_array() {
  declare -p "$1" >/dev/null 2>&1 \
    || die "packages.conf: array '$1' is not defined (typo?)"
}

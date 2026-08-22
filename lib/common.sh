# shellcheck shell=bash
#
# lib/common.sh -- shared helpers: output, system detection, and the small set
# of primitives that actually change the machine.
#
# Sourced by setup.sh and sync.sh before any other lib/ file. It defines no
# policy of its own; it is the vocabulary the other modules are written in.
#
# Globals it expects the caller to have set before sourcing:
#   DRY_RUN     true|false   run() and friends print instead of acting
#   ASSUME_YES  true|false   confirm() returns success without asking
#   SKIP        comma list   consulted by skipped()
#
# Globals it sets:
#   OS          macos|linux            (detect_system)
#   PM          brew|apt|dnf|pacman    (detect_system)
#   DISTRO      macos|debian|fedora|arch|cachyos|...  (detect_system)
#               informational only -- nothing branches on it
#   _c_*        terminal colour escapes, empty when not a tty
#
# Targets bash 3.2 -- that is what /bin/bash is on macOS, and it runs before
# Homebrew exists. So no associative arrays, no mapfile, no ${var,,}, and
# empty arrays must be expanded as ${arr[@]+"${arr[@]}"} under set -u.

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# Colour only when stdout is a terminal, so redirected output and CI logs stay
# clean. NO_COLOR is the de-facto standard opt-out (https://no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_green=$'\033[32m'
  _c_blue=$'\033[34m'; _c_dim=$'\033[2m'; _c_off=$'\033[0m'
else
  _c_red=''; _c_yellow=''; _c_green=''; _c_blue=''; _c_dim=''; _c_off=''
fi

# The output vocabulary, roughly in order of importance. Warnings and errors
# go to stderr so a caller can filter them out of normal progress reporting.
#
#   log   "==> Heading"    a top-level step
#   info  "    detail"     a detail under the current step
#   dim   "    detail"     the same, de-emphasised (skips, no-ops)
#   ok    "  ✓ result"     something succeeded
#   warn  "  ! problem"    recoverable; execution continues        -> stderr
#   die   "error: fatal"   unrecoverable; exits 1                  -> stderr
log()   { printf '%s==>%s %s\n' "$_c_blue" "$_c_off" "$*"; }
info()  { printf '    %s\n' "$*"; }
dim()   { printf '%s    %s%s\n' "$_c_dim" "$*" "$_c_off"; }
ok()    { printf '%s  ✓%s %s\n' "$_c_green" "$_c_off" "$*"; }
warn()  { printf '%s  ! %s%s\n' "$_c_yellow" "$*" "$_c_off" >&2; }
die()   { printf '%serror:%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }

# confirm <prompt>
# Returns 0 to proceed, 1 to abort.
#
# Answers itself under --yes, and also when stdin is not a terminal -- a
# container or a pipe cannot answer, and blocking forever there is worse than
# proceeding. Callers that must not proceed unattended should check the
# situation themselves rather than relying on this.
confirm() {
  $ASSUME_YES && return 0
  [ -t 0 ] || return 0
  printf '%s [y/N] ' "$1"
  local reply=''
  read -r reply
  case "$reply" in [yY] | [yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# run <command> [args...]
# Executes the command, or prints it and returns 0 under --dry-run.
#
# Only works for plain commands: pipes, redirects and shell builtins cannot be
# passed through "$@". Anything with a pipeline handles --dry-run itself --
# see fetch_and_run below, or rsync_dir in lib/config.sh.
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

# _os_release_id  ->  the ID= field of /etc/os-release, or empty
#
# Parsed, not sourced: sourcing os-release would drag twenty unrelated
# variables into the shell. tr strips the quotes some distros put round the
# value; head -1 guards against a second ID= line further down the file.
_os_release_id() {
  [ -r /etc/os-release ] || return 0
  sed -n 's/^ID=//p' /etc/os-release | head -1 | tr -d "\"'"
}

# detect_system
# Sets OS, PM and DISTRO. Call once, early; everything else branches on the
# first two.
#
# macOS has no native package manager, so PM=brew there and the native-install
# path is simply skipped. On Linux the first manager found wins -- order
# matters only on systems carrying more than one, where the native one is
# listed first. Derivatives fall out of this for free: CachyOS and Manjaro are
# recognised by the pacman they carry, not by a name in a list here.
#
# DISTRO is reported, never branched on. Code that needs distro-specific
# behaviour probes for the thing it actually needs -- `command -v paru`, or the
# cachyos-config.fish test in config/fish/config.fish -- which is what lets a
# derivative work without this file having heard of it.
# shellcheck disable=SC2034  # all three are read by the other lib/ files
detect_system() {
  case "${OSTYPE:-}" in
    darwin*)
      OS=macos
      PM=brew
      DISTRO=macos
      ;;
    *)
      OS=linux
      DISTRO="$(_os_release_id)"
      [ -n "$DISTRO" ] || DISTRO=linux
      if   command -v apt-get >/dev/null 2>&1; then PM=apt
      elif command -v dnf     >/dev/null 2>&1; then PM=dnf
      elif command -v pacman  >/dev/null 2>&1; then PM=pacman
      else die "no supported package manager found (need apt, dnf or pacman)"
      fi
      ;;
  esac
}

# require_not_root
# Exits unless running as an unprivileged user.
#
# Everything here belongs to one user; the few commands that genuinely need
# elevation call sudo themselves. Running the whole script as root writes
# root-owned files into a user's ~/.config, which is what the previous version
# did and then papered over with a chown -R afterwards. Homebrew and makepkg
# both refuse to run as root anyway.
require_not_root() {
  [ "$(id -u)" -ne 0 ] || die "do not run as root -- run as your normal user; sudo is called only where needed

  If you used the curl one-liner with sudo, re-run it without."
}

# skipped <step>
# True when the step was named in --skip=a,b,c
#
# The comma padding on both sides makes it an exact whole-word match, so
# --skip=brewery does not match the "brew" step.
skipped() {
  case ",$SKIP," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Mutating primitives -- each safe to run repeatedly
# ---------------------------------------------------------------------------

_MARKER='# >>> penguin_setup >>>'

# append_line_once <file> <line>
# Appends the line unless it is already present verbatim.
#
# grep -qxF: exact whole-line, fixed-string match, so a line containing shell
# metacharacters is not treated as a pattern. The marker comments make the
# block greppable and easy to remove by hand later.
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
# Creates or repoints a symlink; no-op when it already points at the target.
#
# ln -sfn, never `[ ! -e "$link" ] && ln -s ...`: -e follows the link and is
# false for a *dangling* symlink, so the guard passes, ln runs, and then fails
# because the name already exists. -n stops ln descending into a link that
# points at a directory.
symlink() {
  local target="$1" link="$2"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    return 0
  fi
  run ln -sfn "$target" "$link"
}

# fetch_and_run <url> <interpreter>
# Downloads a script, verifies it is non-empty, then executes it.
#
# Deliberately not `curl ... | sh`: without -f, curl hands the body of an HTTP
# error page to the interpreter and a 404 becomes executed shell. Downloading
# first also means a truncated transfer is caught by the size check rather
# than half-executed. The RETURN trap cleans up on every exit path.
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

# require_array <name>
# Exits if no array by that name was defined in packages.conf.
#
# Guards against a typo silently reading as empty under set -u, which would
# install nothing and report success. declare -p, not ${x+set}: the latter
# tests element 0, so it reports a legitimately empty array (BREW_CASKS=())
# as missing.
require_array() {
  declare -p "$1" >/dev/null 2>&1 \
    || die "packages.conf: array '$1' is not defined (typo?)"
}

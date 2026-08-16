#!/usr/bin/env bash
#
# Post-install assertions. Runs inside the container as the test user, after
# setup.sh has returned 0.
#
# Assumes a --headless install: desktop configs must be absent.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

FAILED=0
FAST=false
[ "${1:-}" = --fast ] && FAST=true

pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗ %s\033[0m\n' "$*"; FAILED=$((FAILED + 1)); }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

printf '\n=== smoke tests ===\n\n'

# --- shell -----------------------------------------------------------------

check "fish is installed" command -v fish

fish_bin="$(command -v fish 2>/dev/null || true)"
if [ -n "$fish_bin" ] && grep -qxF "$fish_bin" /etc/shells 2>/dev/null; then
  pass "fish registered in /etc/shells"
else
  fail "fish registered in /etc/shells"
fi

# --- configs landed --------------------------------------------------------

for d in atuin btop fish git nvim yazi zellij; do
  if [ -d "$HOME/.config/$d" ] && [ -n "$(ls -A "$HOME/.config/$d" 2>/dev/null)" ]; then
    pass "config present: $d"
  else
    fail "config present: $d"
  fi
done

# --headless must not have installed desktop configs, and the Omarchy ones
# should be gone from the repo entirely.
for d in ghostty kitty zed hypr waybar walker fastfetch; do
  if [ -e "$HOME/.config/$d" ]; then
    fail "desktop/removed config must be absent under --headless: $d"
  else
    pass "absent as expected: $d"
  fi
done

# --- ownership -------------------------------------------------------------
# The old setup rsynced as root then chown'd afterwards. Nothing should be
# owned by anyone but us now.

if [ -z "$(find "$HOME/.config" ! -user "$(id -un)" -print -quit 2>/dev/null)" ]; then
  pass "no root-owned files under ~/.config"
else
  fail "no root-owned files under ~/.config"
  find "$HOME/.config" ! -user "$(id -un)" -print 2>/dev/null | head -5
fi

# --- fish actually starts clean --------------------------------------------
# The highest-value check here: it is what catches a config that references a
# tool which is not installed. Under --fast the brew tools are absent by
# design, which is exactly the condition the command -q guards exist for.

out="$(fish -lic 'exit' 2>&1)"
if printf '%s' "$out" | grep -qiE 'command not found|unknown command|^fish:.*error'; then
  fail "fish starts without errors"
  printf '%s\n' "$out" | head -20
else
  pass "fish starts without errors"
fi

# --- fisher ----------------------------------------------------------------

if $FAST; then
  printf '  \033[2m- skipping fisher check (--fast)\033[0m\n'
else
  check "fisher is available" fish -c 'functions -q fisher'
fi

# --- git config.local ------------------------------------------------------

check "git config.local written" test -f "$HOME/.config/git/config.local"
check "git config include resolves" sh -c \
  'git config --get user.name >/dev/null'

# --- dry run changes nothing -----------------------------------------------

sentinel="$(mktemp)"
sleep 1
./sync.sh pull --dry-run --headless >/dev/null 2>&1
if [ -z "$(find "$HOME/.config" -newer "$sentinel" -print -quit 2>/dev/null)" ]; then
  pass "sync.sh pull --dry-run changed nothing"
else
  fail "sync.sh pull --dry-run changed nothing"
fi
rm -f "$sentinel"

# --- idempotency -----------------------------------------------------------
# A second run must succeed and must not be doing work again.

skip_arg=''
$FAST && skip_arg='--skip=brew,aur,uv,upgrade'
if ./setup.sh --headless --yes $skip_arg >/tmp/rerun.log 2>&1; then
  pass "second setup.sh run succeeds"
else
  fail "second setup.sh run succeeds"
  tail -20 /tmp/rerun.log
fi

# --- report ----------------------------------------------------------------

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf '\033[32mall smoke tests passed\033[0m\n\n'
  exit 0
fi
printf '\033[31m%d smoke test(s) failed\033[0m\n\n' "$FAILED"
exit 1

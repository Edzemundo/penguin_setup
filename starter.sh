#!/usr/bin/env bash
#
# Bootstrap penguin_setup on a fresh machine.
#
#   curl -fsSL https://raw.githubusercontent.com/Edzemundo/penguin_setup/main/starter.sh | bash
#   curl -fsSL .../starter.sh | bash -s -- --headless
#
# Any arguments are passed through to setup.sh. Safe to re-run: an existing
# checkout is updated rather than re-cloned.
#
# This is the only file a new machine fetches directly, so it stays small
# enough to read in full before running it -- which is the honest answer to
# "should I pipe this into bash". Everything it does is: clone or update a
# checkout, then hand over to setup.sh.

set -euo pipefail

# Overridable so a fork or a local checkout can be tested without editing the
# script: PENGUIN_REPO=/path/to/repo PENGUIN_DIR=/tmp/x ./starter.sh
REPO_URL="${PENGUIN_REPO:-https://github.com/Edzemundo/penguin_setup.git}"
DEST="${PENGUIN_DIR:-$HOME/.local/share/penguin_setup}"

if [ "$(id -u)" -eq 0 ]; then
  echo "error: run this as your normal user, not root or sudo." >&2
  echo "setup.sh calls sudo only for the commands that need it." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || {
  echo "error: git is required. Install it and re-run." >&2
  exit 1
}

# Update in place rather than cloning unconditionally -- the previous version
# ran `git clone` every time and so failed outright on the second run.
# --ff-only refuses to merge: if the checkout has diverged, that is a decision
# for a human, not a bootstrap script.
if [ -d "$DEST/.git" ]; then
  echo "==> updating $DEST"
  git -C "$DEST" pull --ff-only || {
    echo "error: could not fast-forward $DEST -- resolve it by hand." >&2
    exit 1
  }
else
  echo "==> cloning into $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --depth 1 "$REPO_URL" "$DEST"
fi

cd "$DEST"
chmod +x setup.sh sync.sh test/*.sh 2>/dev/null || true
exec ./setup.sh "$@"

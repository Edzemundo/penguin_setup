#!/usr/bin/env bash
#
# Run the setup in a container.
#
# Usage:
#   test/run.sh <debian|fedora|arch|all> [options]
#
# Options:
#   --fast       skip Homebrew, the AUR and uv (about a minute instead of ten)
#   --shell      drop into a shell in the container instead of running setup
#   --lint       run shellcheck over the scripts and exit
#   --keep       do not remove the container afterwards
#   -h, --help   this message
#
# The repo is bind-mounted read-only and copied inside the container, so a
# test run can never modify your working tree.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

TARGET=''
FAST=false
SHELL_MODE=false
LINT=false
KEEP=false

usage() { sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    debian|fedora|arch|all) TARGET="$1" ;;
    --fast)   FAST=true ;;
    --shell)  SHELL_MODE=true ;;
    --lint)   LINT=true ;;
    --keep)   KEEP=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v docker >/dev/null 2>&1 || {
  echo "docker is not installed or not on PATH" >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "docker does not appear to be running" >&2
  exit 1
}

image_for() {
  case "$1" in
    debian) printf 'debian:stable-slim' ;;
    fedora) printf 'fedora:latest' ;;
    arch)   printf 'archlinux:latest' ;;
  esac
}

# ---------------------------------------------------------------------------

lint() {
  echo "==> shellcheck"
  docker run --rm -v "$REPO:/mnt:ro" -w /mnt koalaman/shellcheck-alpine:stable \
    shellcheck -x -S warning setup.sh sync.sh lib/*.sh test/run.sh test/smoke.sh
  echo "shellcheck clean"
}

build() {
  local distro="$1" base
  base="$(image_for "$distro")"
  echo "==> building penguin-test:$distro  ($base)"
  docker build \
    --build-arg "BASE_IMAGE=$base" \
    -f test/Dockerfile \
    -t "penguin-test:$distro" \
    . >/dev/null
}

run_one() {
  local distro="$1"
  build "$distro"

  local rm_flag=--rm
  $KEEP && rm_flag=''

  # Copy out of the read-only mount so the container can write, and so the
  # host working tree cannot be touched no matter what the scripts do.
  local prelude='cp -a /mnt ~/penguin_setup && cd ~/penguin_setup'

  if $SHELL_MODE; then
    echo "==> shell in $distro (repo at ~/penguin_setup)"
    # shellcheck disable=SC2086  # rm_flag is intentionally unquoted
    exec docker run $rm_flag -it -v "$REPO:/mnt:ro" "penguin-test:$distro" \
      bash -c "$prelude && exec bash"
  fi

  local setup_args='--headless --yes'
  local smoke_args=''
  if $FAST; then
    setup_args="$setup_args --skip=brew,aur,uv,upgrade"
    smoke_args='--fast'
  fi

  echo "==> running setup in $distro ($([ "$FAST" = true ] && echo fast || echo full))"
  # shellcheck disable=SC2086
  docker run $rm_flag -v "$REPO:/mnt:ro" "penguin-test:$distro" bash -c "
    set -e
    $prelude
    ./setup.sh $setup_args
    ./test/smoke.sh $smoke_args
  "
}

main() {
  if $LINT; then lint; exit 0; fi
  [ -n "$TARGET" ] || { printf 'specify a distro\n\n' >&2; usage >&2; exit 2; }

  if [ "$TARGET" != all ]; then
    run_one "$TARGET"
    echo
    echo "PASS: $TARGET"
    return 0
  fi

  local distro failed=''
  for distro in debian fedora arch; do
    echo
    echo "############ $distro ############"
    if run_one "$distro"; then
      echo "PASS: $distro"
    else
      echo "FAIL: $distro"
      failed="$failed $distro"
    fi
  done

  echo
  if [ -n "$failed" ]; then
    echo "failed:$failed"
    exit 1
  fi
  echo "all distros passed"
}

main

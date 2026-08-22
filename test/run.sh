#!/usr/bin/env bash
#
# Run the setup in a container.
#
# Usage:
#   test/run.sh <debian|fedora|arch|cachyos|all> [options]
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
#
# ---------------------------------------------------------------------------
# Why one Dockerfile and a bind mount
#
# One parameterised image, not three: the previous version kept Debian and
# Fedora in a single file with the Fedora half commented out, and it had
# clearly not been run in a long time. Parallel copies rot; a detecting
# bootstrap does not.
#
# Bind-mount rather than COPY: COPY invalidates the layer cache on every
# script edit, so each iteration became a full rebuild. Mounting read-only and
# copying inside means the image is built once and edits cost nothing.
#
# macOS cannot be containerised, so this covers the Linux paths only, and
# --headless only -- there is no desktop session in a container.
# ---------------------------------------------------------------------------

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
    debian|fedora|arch|cachyos|all) TARGET="$1" ;;
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
    debian)  printf 'debian:stable-slim' ;;
    fedora)  printf 'fedora:latest' ;;
    arch)    printf 'archlinux:latest' ;;
    cachyos) printf 'cachyos/cachyos:latest' ;;
  esac
}

# Arch and CachyOS publish x86_64 images only, so on an arm64 host (Apple
# Silicon) they have to run under emulation. Everything else uses the native
# architecture. Emulated runs work but are several times slower.
#
# Every path returns 0: this is called as platform="$(platform_for ...)" under
# set -e, where a non-zero status would abort the run rather than mean "native".
platform_for() {
  case "$1" in
    arch|cachyos) [ "$(uname -m)" = x86_64 ] || printf 'linux/amd64' ;;
  esac
}

# ---------------------------------------------------------------------------

# lint
# Runs shellcheck from a container, so no linter has to be installed locally.
# -x follows `source` directives into lib/, which is the only way it can check
# the sourced files in context.
lint() {
  echo "==> shellcheck"
  docker run --rm -v "$REPO:/mnt:ro" -w /mnt koalaman/shellcheck-alpine:stable \
    shellcheck -x -S warning setup.sh sync.sh lib/*.sh test/run.sh test/smoke.sh
  echo "shellcheck clean"
}

build() {
  local distro="$1" base platform
  base="$(image_for "$distro")"
  platform="$(platform_for "$distro")"

  if [ -n "$platform" ]; then
    echo "==> building penguin-test:$distro  ($base, emulated $platform)"
  else
    echo "==> building penguin-test:$distro  ($base)"
  fi

  # shellcheck disable=SC2086  # platform flag is empty when not needed
  docker build \
    ${platform:+--platform "$platform"} \
    --build-arg "BASE_IMAGE=$base" \
    -f test/Dockerfile \
    -t "penguin-test:$distro" \
    . >/dev/null
}

# run_one <distro>
# Builds the image, runs setup.sh inside it, then runs the smoke tests.
# Returns the container's exit status.
run_one() {
  local distro="$1" platform
  build "$distro"
  platform="$(platform_for "$distro")"

  local rm_flag=--rm
  $KEEP && rm_flag=''

  # Copy out of the read-only mount so the container can write, and so the
  # host working tree cannot be touched no matter what the scripts do.
  local prelude='cp -a /mnt ~/penguin_setup && cd ~/penguin_setup'

  if $SHELL_MODE; then
    echo "==> shell in $distro (repo at ~/penguin_setup)"
    # shellcheck disable=SC2086  # rm_flag and platform are intentionally unquoted
    exec docker run $rm_flag ${platform:+--platform "$platform"} \
      -it -v "$REPO:/mnt:ro" "penguin-test:$distro" \
      bash -c "$prelude && exec bash"
  fi

  # --headless because a container has no desktop, and --yes because there is
  # nobody to answer a prompt.
  local setup_args='--headless --yes'
  local smoke_args=''
  if $FAST; then
    # Homebrew on Linux builds from source whenever there is no bottle, and
    # dominates the runtime. Skipping it still exercises everything this
    # rewrite actually changed: the manifest, config sync, excludes, dry-run
    # inertness, fish, fisher and idempotency.
    setup_args="$setup_args --skip=brew,aur,uv,upgrade"
    smoke_args='--fast'
  fi

  echo "==> running setup in $distro ($([ "$FAST" = true ] && echo fast || echo full))"
  # shellcheck disable=SC2086
  docker run $rm_flag ${platform:+--platform "$platform"} \
    -v "$REPO:/mnt:ro" "penguin-test:$distro" bash -c "
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
  for distro in debian fedora arch cachyos; do
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

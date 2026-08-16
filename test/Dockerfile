# Test image for penguin_setup.
#
# One file covers every distro: the bootstrap detects the package manager
# rather than keeping a commented-out branch per distro, which is how the
# previous version's Fedora path quietly stopped working.
#
#   docker build -f test/Dockerfile --build-arg BASE_IMAGE=fedora:latest .
#
# The repo is bind-mounted at run time, not COPYed, so editing a script does
# not invalidate the layer cache.

ARG BASE_IMAGE=debian:stable-slim
FROM ${BASE_IMAGE}

# Non-interactive apt, ignored elsewhere.
ENV DEBIAN_FRONTEND=noninteractive

# pacman 7 sandboxes itself with seccomp, which fails under qemu emulation
# (Arch publishes x86_64 images only, so it is emulated on Apple Silicon).
# DisableSandbox is written into pacman.conf below, before pacman is first
# used, so it applies to setup.sh's own pacman calls too. Test images only.

# Note the deliberate absence of && between the update and install steps:
# `set -e` is suppressed inside an && list, so chaining them would let a failed
# package-database refresh pass silently and produce an image with nothing
# installed. Separate statements let set -e do its job.
RUN set -eux; \
    if   command -v apt-get >/dev/null 2>&1; then \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            sudo passwd ca-certificates curl git rsync procps file locales; \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null 2>&1; then \
        dnf -y install \
            sudo passwd ca-certificates curl git rsync procps-ng file findutils; \
        dnf clean all; \
    elif command -v pacman >/dev/null 2>&1; then \
        printf 'DisableSandbox\n' >> /etc/pacman.conf; \
        pacman -Syu --noconfirm; \
        pacman -S --needed --noconfirm \
            sudo curl git rsync which base-devel; \
        pacman -Scc --noconfirm; \
    else \
        echo "unsupported base image: no apt/dnf/pacman" >&2; exit 1; \
    fi

# Homebrew on Linux needs a real locale and a writable prefix.
ENV LANG=C.UTF-8

# Debian calls the sudo group "sudo", Arch and Fedora call it "wheel".
# Creating and permitting both removes the per-distro branch entirely.
RUN set -eux; \
    getent group wheel >/dev/null || groupadd wheel; \
    getent group sudo  >/dev/null || groupadd sudo; \
    useradd -m -s /bin/bash -G wheel,sudo tester; \
    mkdir -p /etc/sudoers.d; \
    printf '%%wheel ALL=(ALL) NOPASSWD: ALL\n%%sudo ALL=(ALL) NOPASSWD: ALL\n' \
        > /etc/sudoers.d/99-tester; \
    chmod 0440 /etc/sudoers.d/99-tester; \
    mkdir -p /home/linuxbrew && chown tester:tester /home/linuxbrew

USER tester
WORKDIR /home/tester
CMD ["bash"]

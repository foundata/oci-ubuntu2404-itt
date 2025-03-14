FROM ubuntu:24.04
LABEL description="Ubuntu 24.04 LTS (Noble Numbat), Integration Test Target (ITT) with systemd"
LABEL maintainer="foundata GmbH (https://foundata.com)"

# Inform systemd it's running in a container and specifies the container manager
# type. This affects systemd's behavior in containerized environments (see
# systemd's src/basic/virt.c). Docker users can overwrite this with
# "--env container=docker".
ENV container=podman

# Ensure Python output goes directly to terminal without buffering, preventing
# loss of partial output if an application crashes.
ENV PYTHONUNBUFFERED=1

# Build-time for the package manager (apt), prevents interactive prompts during
# package installation
ARG DEBIAN_FRONTEND=noninteractive

# Install systemd, remove inconvenient targets and services. Helpful resources
# to determine problematic units to be removed during development:
#   systemctl list-dependencies
#   systemctl list-units --state=waiting
#   systemctl list-units --state=failed
#   https://www.freedesktop.org/software/systemd/man/latest/bootup.html
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-cron \
    # General
    && rm -rf "/lib/systemd/system/basic.target.wants/"* \
    && rm -f "/lib/systemd/system/sockets.target.wants/"*"udev"* \
    && rm -f "/lib/systemd/system/sockets.target.wants/"*"initctl"* \
    && rm -f "/lib/systemd/system/"*"ask-password"* \
    # Ubuntu specific
    # Prevent start of agetty on tty[1-6].
    && rm -f "/lib/systemd/system/multi-user.target.wants/getty.target" \
    # Clean up unnecessary installed files that aren't needed in this image
    && rm -rf "/usr/share/doc" \
    && rm -rf "/usr/share/man"

# Install required packages and clean-up package manager caches afterwards.
# Packages are included for these purposes:
#
# - Overall compatibility and network functionality:
#   build-essential iproute2 libffi-dev libssl-dev locales procps
#
# - Easier debugging within the container (good feature-to-size ratio):
#   iputils-ping, iputils-tracepath, less, vim-tiny
#
# - Accessing a VM via Ansible:
#   python3, python3-apt, sudo
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        iproute2 \
        libffi-dev \
        libssl-dev \
        locales \
        procps \
        iputils-ping \
        iputils-tracepath \
        less \
        vim-tiny \
        python3 \
        python3-apt \
        sudo \
    && rm -rf "/var/lib/apt/lists/"* \
    && apt-get clean \
    # Clean up unnecessary installed files that aren't needed in this image
    && rm -rf "/usr/share/doc" \
    && rm -rf "/usr/share/man"

# Prevent UTF-8 errors or warnings raised by several tools
RUN locale-gen en_US.UTF-8

# Ensure non-interactive sudo commands work in containerized environments where
# TTY allocation is often unavailable or undesired (if needed, it is usually
# allowed on this platform).
RUN sed -i -e 's/\(^Defaults\s*\)\(requiretty\)/\1!\2/' "/etc/sudoers"

# Define volumes for systemd (Podman will do this automatically, but let's add
# this for best-effort Docker compatibility)
VOLUME ["/run", "/run/lock", "/tmp", "/sys/fs/cgroup/systemd", "/var/lib/journal" ]

# Start systemd init
CMD ["/lib/systemd/systemd"]

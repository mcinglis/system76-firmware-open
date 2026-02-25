# syntax=docker/dockerfile:1

# Dockerfile to build firmware-open for a chosen model. Easiest to build with:
#
#     ./scripts/build-docker.sh qemu
#
# Or just with a direct invocation, like:
#
#     docker build -v=$PWD/build:/opt/firmware-open/build --build-arg=MODEL=qemu .
#
# This produces firmware build artifacts in ./build/ ready for flashing
# without any build toolchain required; see docs/flashing.md for details.
#
# To build only the base environment container, not building the firmware, run:
#
#     docker build --target=prebuild .


# ----------------------------
# firmware-open prebuild stage
# ----------------------------

# Debian "trixie" 13; supported until 2030-06-30.
# https://hub.docker.com/layers/library/debian/trixie-slim/
FROM debian:trixie-slim@sha256:1d3c811171a08a5adaa4a163fbafd96b61b87aa871bbc7aa15431ac275d3d430 AS prebuild

# Better build reproducibility:
ENV SOURCE_DATE_EPOCH=0 LC_ALL=C LANG=C

# Using snapshot repositories; https://snapshot.debian.org/
ARG DEBIAN_SNAPSHOT="20260304T000000Z"
COPY <<EOF /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}
Suites: trixie trixie-updates bookworm
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
Check-Valid-Until: no

Types: deb
URIs: http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
Check-Valid-Until: no
EOF

# Wrap apt-get to cryptographically verify package lists after each command;
# note that /usr/local/bin precedes /usr/bin in Debian's PATH.
COPY --chmod=755 <<'EOF' /usr/local/bin/apt-get
#!/bin/sh
set -eux
DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --quiet=0 "$@"
sha256sum -c <<CHECKSUMS_EOF
e59ba40ac9589ca5c5e38effb803a50ee352aa5d6810436c77b7bc701bc25902  /var/lib/apt/lists/snapshot.debian.org_archive_debian-security_20260304T000000Z_dists_trixie-security_InRelease
b5c149281c1fe8ff18b1385d9fcbc3bc6663f33f0baa027de49c48da73b5ea7f  /var/lib/apt/lists/snapshot.debian.org_archive_debian_20260304T000000Z_dists_bookworm_InRelease
b8ae3b067b6cc5e720d9ffa5ab970091777ea29ae314a7d236c90a6dd432e34a  /var/lib/apt/lists/snapshot.debian.org_archive_debian_20260304T000000Z_dists_trixie-updates_InRelease
59bcb7bc2e221c6e7d2361adf8f82dfbd28ad8d755f2fe42f56d3be42fd25a4c  /var/lib/apt/lists/snapshot.debian.org_archive_debian_20260304T000000Z_dists_trixie_InRelease
CHECKSUMS_EOF
EOF

WORKDIR /opt/firmware-open

# Scripts require sudo on the PATH:
RUN <<EOF
set -eux
apt-get update
apt-get install --assume-yes --no-install-recommends sudo
EOF

# Install firmware-open's dependencies:
COPY ./scripts/install-deps.sh ./scripts/
RUN ./scripts/install-deps.sh

# Install ec's dependencies, and downgrade off SDC 4.5.0 which builds
# the ec.rom incorrectly per https://github.com/system76/ec/issues/518
COPY ./ec/scripts/deps.sh ./ec/scripts/
RUN <<EOF
set -eux
./ec/scripts/deps.sh
apt-get update
apt-get install --assume-yes --no-install-recommends --allow-downgrades \
    sdcc=4.2.0+dfsg-1 \
    sdcc-libraries=4.2.0+dfsg-1
EOF

# Install and build coreboot's dependencies:
COPY ./scripts/coreboot-sdk.sh ./scripts/
COPY ./coreboot ./coreboot
COPY ./.git/modules/coreboot ./.git/modules/coreboot
RUN ./scripts/coreboot-sdk.sh -u


# -------------------------
# firmware-open build stage
# -------------------------

FROM prebuild

# Filter container build context here, not .dockerignore:
COPY --exclude=Dockerfile --exclude=.dockerignore --exclude=build/ . .

ARG MODEL=qemu

# Build the firmware-open distribution:
RUN ./scripts/build.sh ${MODEL}

# Pre-build firmware-update for scripts/flash.sh:
RUN <<EOF
set -eux
make -C apps/firmware-update TARGET=x86_64-unknown-uefi
mkdir -p build/${MODEL}/firmware-update
cp -r \
    apps/firmware-update/build/x86_64-unknown-uefi/boot.efi \
    apps/firmware-update/res \
    build/${MODEL}/firmware-update/
EOF


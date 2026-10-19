#!/usr/bin/env bash
# build-freebsd.sh <target> [out_dir]
# Extracts FreeBSD base sysroot (libraries and headers) from official release sets
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-x86_64-unknown-freebsd}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include" "$SYSROOT/lib"

FREEBSD_VERSION="14.4"
MACHINE="amd64"

case "$TARGET" in
    x86_64-unknown-freebsd)
        MACHINE="amd64"
        ;;
    *)
        log_err "Unknown FreeBSD target: $TARGET"
        ;;
esac

log "Downloading FreeBSD $FREEBSD_VERSION $MACHINE base set..."
RELEASE="${FREEBSD_VERSION}-RELEASE"
BASE_TXZ="$WORK/base.txz"

fetch_any "$BASE_TXZ" \
    "https://download.freebsd.org/releases/${MACHINE}/${RELEASE}/base.txz" \
    "https://ftpmirror.your.org/pub/FreeBSD-Archive/old-releases/${MACHINE}/${RELEASE}/base.txz" \
    "https://archive.freebsd.org/old-releases/${MACHINE}/${RELEASE}/base.txz"

log "Extracting FreeBSD sysroot..."
tar -xJf "$BASE_TXZ" -C "$SYSROOT" ./lib ./usr/lib ./usr/include

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"

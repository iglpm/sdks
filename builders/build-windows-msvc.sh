#!/usr/bin/env bash
# build-windows-msvc.sh <target> [out_dir]
# Packages MSVC CRT & Windows SDK stubs for MSVC cross-linking via hyprlnk
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-x86_64-pc-windows-msvc}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/lib" "$SYSROOT/include" "$SYSROOT/ucrt" "$SYSROOT/um"

case "$TARGET" in
    x86_64-pc-windows-msvc)
        ARCH_DIR="x64"
        ;;
    aarch64-pc-windows-msvc)
        ARCH_DIR="arm64"
        ;;
    i686-pc-windows-msvc)
        ARCH_DIR="x86"
        ;;
    *)
        log_err "Unknown Windows MSVC target: $TARGET"
        ;;
esac

log "Packaging Windows MSVC SDK for $TARGET ($ARCH_DIR)..."

# If xwin or msvc-wine sysroot is available, export it:
# xwin can fetch the official CRT & Windows SDK headers and libs without a Windows license
if ! command -v xwin >/dev/null 2>&1; then
    log "Installing cargo-xwin / xwin..."
    if command -v cargo >/dev/null 2>&1; then
        cargo install --locked xwin || true
    fi
fi

if command -v xwin >/dev/null 2>&1; then
    log "Running xwin unpack..."
    xwin --accept-license --arch "$ARCH_DIR" splat --output "$SYSROOT"
else
    log_warn "xwin not available on PATH; creating minimal stub MSVC layout"
    mkdir -p "$SYSROOT/lib/$ARCH_DIR"
    mkdir -p "$SYSROOT/ucrt/$ARCH_DIR"
    mkdir -p "$SYSROOT/um/$ARCH_DIR"
fi

clean_sysroot "$SYSROOT"
pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"

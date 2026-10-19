#!/usr/bin/env bash
# build-macos.sh <target> [out_dir]
# Packages the macOS SDK into a .tar.xz using Xcode's installed Command Line Tools / SDKs,
# following the packaging approach used by osxcross (tools/gen_sdk_package.sh).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-MacOSX.sdk}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log "Locating macOS SDK..."

SDK_PATH=""
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
elif [ -d "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]; then
    SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
elif command -v xcrun >/dev/null 2>&1; then
    SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
fi

if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
    log_err "No macOS SDK found. Ensure Command Line Tools or Xcode is installed."
fi

log "Packaging macOS SDK from $SDK_PATH..."

# Resolve real path in case of symlink (e.g. MacOSX.sdk -> MacOSX15.sdk)
REAL_SDK="$(cd "$SDK_PATH" && pwd -P)"
SDK_DIRNAME="$(basename "$REAL_SDK")"

# Clone/copy the SDK directory structure
DEST_SDK="$WORK/$SDK_DIRNAME"
mkdir -p "$DEST_SDK"
cp -a "$REAL_SDK/." "$DEST_SDK/"

# Ensure headers from Toolchains are included if libc++ headers are separate (standard osxcross practice)
TOOLCHAIN_USR="/Library/Developer/CommandLineTools/usr/include"
if [ -d "$TOOLCHAIN_USR/c++" ] && [ ! -d "$DEST_SDK/usr/include/c++" ]; then
    log "Adding C++ standard library headers from Toolchain..."
    mkdir -p "$DEST_SDK/usr/include"
    cp -a "$TOOLCHAIN_USR/c++" "$DEST_SDK/usr/include/"
fi

# Clean unnecessary bloated assets
rm -rf "$DEST_SDK"/usr/share/{man,doc,locale} 2>/dev/null || true

# Package the SDK archive
OUT_TAR="$OUT_DIR/MacOSX.sdk.tar.xz"
pack_tarball "$DEST_SDK" "$OUT_TAR"

# Also symlink/copy for specific target names if requested
if [ "$TARGET" = "aarch64-apple-darwin" ] || [ "$TARGET" = "x86_64-apple-darwin" ]; then
    cp "$OUT_TAR" "$OUT_DIR/${TARGET}.tar.xz"
fi

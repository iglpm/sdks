#!/usr/bin/env bash
# build-linux-gnu.sh <target> [out_dir]
# Builds/extracts a lightweight Linux glibc sysroot for cross-linking
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../scripts/common.sh"

TARGET="${1:-x86_64-unknown-linux-gnu}"
OUT_DIR="${2:-dist}"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SYSROOT="$WORK/sysroot"
mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include" "$SYSROOT/lib"

case "$TARGET" in
    x86_64-unknown-linux-gnu)
        DEB_ARCH="amd64"
        GNU_TRIPLE="x86_64-linux-gnu"
        PACKAGES="libc6-dev libc6"
        ;;
    i686-unknown-linux-gnu)
        DEB_ARCH="i386"
        GNU_TRIPLE="i386-linux-gnu"
        PACKAGES="libc6-dev-i386-cross libc6-i386-cross libc6-dev-i386 gcc-multilib"
        ;;
    aarch64-unknown-linux-gnu)
        DEB_ARCH="arm64"
        GNU_TRIPLE="aarch64-linux-gnu"
        PACKAGES="libc6-dev-arm64-cross libc6-arm64-cross libgcc-s1-arm64-cross libgcc-13-dev-arm64-cross"
        ;;
    armv7-unknown-linux-gnueabihf)
        DEB_ARCH="armhf"
        GNU_TRIPLE="arm-linux-gnueabihf"
        PACKAGES="libc6-dev-armhf-cross libc6-armhf-cross libgcc-s1-armhf-cross libgcc-13-dev-armhf-cross"
        ;;
    arm-unknown-linux-gnueabi)
        DEB_ARCH="armel"
        GNU_TRIPLE="arm-linux-gnueabi"
        PACKAGES="libc6-dev-armel-cross libc6-armel-cross libgcc-s1-armel-cross libgcc-13-dev-armel-cross"
        ;;
    riscv64gc-unknown-linux-gnu)
        DEB_ARCH="riscv64"
        GNU_TRIPLE="riscv64-linux-gnu"
        PACKAGES="libc6-dev-riscv64-cross libc6-riscv64-cross libgcc-s1-riscv64-cross libgcc-13-dev-riscv64-cross"
        ;;
    powerpc64le-unknown-linux-gnu)
        DEB_ARCH="ppc64el"
        GNU_TRIPLE="powerpc64le-linux-gnu"
        PACKAGES="libc6-dev-ppc64el-cross libc6-ppc64el-cross libgcc-s1-ppc64el-cross libgcc-13-dev-ppc64el-cross"
        ;;
    powerpc64-unknown-linux-gnu)
        DEB_ARCH="ppc64"
        GNU_TRIPLE="powerpc64-linux-gnu"
        PACKAGES="libc6-dev-ppc64-cross libc6-ppc64-cross libgcc-s1-ppc64-cross libgcc-13-dev-ppc64-cross"
        ;;
    powerpc-unknown-linux-gnu)
        DEB_ARCH="powerpc"
        GNU_TRIPLE="powerpc-linux-gnu"
        PACKAGES="libc6-dev-powerpc-cross libc6-powerpc-cross libgcc-s1-powerpc-cross libgcc-13-dev-powerpc-cross"
        ;;
    s390x-unknown-linux-gnu)
        DEB_ARCH="s390x"
        GNU_TRIPLE="s390x-linux-gnu"
        PACKAGES="libc6-dev-s390x-cross libc6-s390x-cross libgcc-s1-s390x-cross libgcc-13-dev-s390x-cross"
        ;;
    sparc64-unknown-linux-gnu)
        DEB_ARCH="sparc64"
        GNU_TRIPLE="sparc64-linux-gnu"
        PACKAGES="libc6-dev-sparc64-cross libc6-sparc64-cross libgcc-s1-sparc64-cross libgcc-13-dev-sparc64-cross"
        ;;
    loongarch64-unknown-linux-gnu)
        DEB_ARCH="loong64"
        GNU_TRIPLE="loongarch64-linux-gnu"
        PACKAGES="libc6-dev-loong64-cross libc6-loong64-cross libgcc-s1-loong64-cross libgcc-13-dev-loong64-cross"
        ;;
    *)
        log_err "Unknown Linux GNU target: $TARGET"
        ;;
esac

log "Building SDK for $TARGET ($GNU_TRIPLE)..."

# Install deb packages or extract from apt cache
apt_install $PACKAGES

# Locate installed cross sysroot files under /usr/$GNU_TRIPLE or multiarch paths
if [ -d "/usr/$GNU_TRIPLE" ]; then
    cp -a /usr/"$GNU_TRIPLE"/lib/. "$SYSROOT/usr/lib/" 2>/dev/null || true
    # SPARC64 ships its dynamic loader in lib64, separate from libc in lib.
    if [ -d "/usr/$GNU_TRIPLE/lib64" ]; then
        cp -a /usr/"$GNU_TRIPLE"/lib64/. "$SYSROOT/usr/lib/"
    fi
    cp -a /usr/"$GNU_TRIPLE"/include/. "$SYSROOT/usr/include/" 2>/dev/null || true
fi

# Also check /usr/lib/$GNU_TRIPLE
if [ -d "/usr/lib/$GNU_TRIPLE" ]; then
    cp -a /usr/lib/"$GNU_TRIPLE"/. "$SYSROOT/usr/lib/" 2>/dev/null || true
fi
if [ -d "/usr/include/$GNU_TRIPLE" ]; then
    cp -a /usr/include/"$GNU_TRIPLE"/. "$SYSROOT/usr/include/" 2>/dev/null || true
fi
if [ -d "/lib/$GNU_TRIPLE" ]; then
    cp -a /lib/"$GNU_TRIPLE"/. "$SYSROOT/lib/" 2>/dev/null || true
fi

# Copy libgcc and crtbegin/crtend from gcc-cross
if [ -d "/usr/lib/gcc-cross/$GNU_TRIPLE" ]; then
    for vdir in /usr/lib/gcc-cross/"$GNU_TRIPLE"/*; do
        if [ -d "$vdir" ]; then
            cp -a "$vdir"/*.a "$SYSROOT/usr/lib/" 2>/dev/null || true
            cp -a "$vdir"/*.o "$SYSROOT/usr/lib/" 2>/dev/null || true
            cp -a "$vdir"/*.so "$SYSROOT/usr/lib/" 2>/dev/null || true
        fi
    done
fi

# For i386 / 32-bit x86, libc6-dev-i386 installs into /usr/lib32 and /usr/include
if [ "$TARGET" = "i686-unknown-linux-gnu" ]; then
    if [ -d "/usr/lib32" ]; then
        cp -a /usr/lib32/. "$SYSROOT/usr/lib/" 2>/dev/null || true
    fi
    if [ -d "/usr/include" ]; then
        # Copy standard headers if sysroot headers are missing
        # libc6-dev-i386 shares the amd64 glibc headers. Copy their complete tree:
        # bits/ and gnu/ can be links into x86_64-linux-gnu, and public headers
        # include additional headers such as features-time64.h and endian.h.
        cp -a /usr/include/. "$SYSROOT/usr/include/"
    fi
fi

# For x86_64, copy host libraries & headers if empty
if [ "$TARGET" = "x86_64-unknown-linux-gnu" ]; then
    if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
        cp -a /usr/lib/x86_64-linux-gnu/. "$SYSROOT/usr/lib/" 2>/dev/null || true
    fi
    if [ -d "/usr/include" ]; then
        cp -a /usr/include/. "$SYSROOT/usr/include/" 2>/dev/null || true
    fi
    if [ -d "/lib/x86_64-linux-gnu" ]; then
        cp -a /lib/x86_64-linux-gnu/. "$SYSROOT/lib/" 2>/dev/null || true
    fi
fi

# Validate sysroot has minimal linking components
if [ ! -f "$SYSROOT/usr/lib/crt1.o" ] && [ ! -f "$SYSROOT/usr/lib/libc.so" ] && [ ! -f "$SYSROOT/usr/lib/libc.a" ]; then
    # Search system for target crt1.o or libc.so and copy
    find /usr -name "crt1.o" 2>/dev/null | grep -E "$GNU_TRIPLE|i386|x86_64" | head -n 1 | while read -r f; do
        d="$(dirname "$f")"
        cp -a "$d"/. "$SYSROOT/usr/lib/" 2>/dev/null || true
    done
fi

# Ensure standard symlinks exist
cd "$SYSROOT"
if [ ! -e "lib64" ] && [ -d "usr/lib" ]; then
    ln -s usr/lib lib64 2>/dev/null || true
fi
if [ ! -e "lib" ] && [ -d "usr/lib" ]; then
    ln -s usr/lib lib 2>/dev/null || true
fi
# The directory is created above, so the missing-path check alone leaves an
# empty lib/ and QEMU cannot find /lib/ld-linux-*.so.*.
if [ -d lib ] && [ ! -L lib ] && rmdir lib 2>/dev/null; then
    ln -s usr/lib lib
fi

# Fix absolute symlinks in sysroot (e.g., libc.so pointing to /lib/...)
find "$SYSROOT" -type l | while read -r symlink; do
    target="$(readlink "$symlink")"
    if [[ "$target" == /* ]]; then
        # Check if relative target exists inside sysroot
        rel_target="$SYSROOT$target"
        if [ -e "$rel_target" ]; then
            ln -sf "$(basename "$target")" "$symlink"
        fi
    fi
done

clean_sysroot "$SYSROOT"

# Some SPARC cross libc-dev packages omit the dynamic loader from libc.so's
# linker group. Rust's TLS support references __tls_get_addr from that loader,
# so include it explicitly just as native glibc linker scripts do.
if [ "$TARGET" = "sparc64-unknown-linux-gnu" ] && \
   [ -f "$SYSROOT/usr/lib/libc.so" ] && \
   ! grep -q 'ld-linux.so.2' "$SYSROOT/usr/lib/libc.so"; then
    sed -i 's| )$| AS_NEEDED ( ld-linux.so.2 ) )|' "$SYSROOT/usr/lib/libc.so"
fi

pack_tarball "$SYSROOT" "$OUT_DIR/${TARGET}.tar.xz"

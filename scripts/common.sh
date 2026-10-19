#!/usr/bin/env bash
# common.sh - Shared utility functions for building and packaging SDKs/sysroots
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() {
    echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"
}

log_step() {
    echo -e "  \033[1;32m✓\033[0m $*"
}

log_warn() {
    echo -e "\033[1;33mwarning:\033[0m $*" >&2
}

log_err() {
    echo -e "\033[1;31merror:\033[0m $*" >&2
    exit 1
}

fetch() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    log "Downloading $url..."
    curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors -sS -o "$dest" "$url"
}

fetch_any() {
    local dest="$1"
    shift
    for url in "$@"; do
        if curl --fail --location --retry 2 -sS -o "$dest" "$url" 2>/dev/null; then
            log_step "Downloaded $url"
            return 0
        fi
    done
    log_err "Failed to download from any mirror: $*"
}

apt_install() {
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends -qq "$@"
}

clean_sysroot() {
    local root="$1"
    log "Cleaning and pruning $root..."
    
    # Remove documentation, man pages, locales, info
    rm -rf "$root"/usr/share/{doc,man,info,locale,zoneinfo} 2>/dev/null || true
    rm -rf "$root"/share/{doc,man,info,locale} 2>/dev/null || true

    # Remove static libraries not required for linking
    find "$root" -type f -name "*.a" \
        -not -name "libc.a" \
        -not -name "libm.a" \
        -not -name "libpthread.a" \
        -not -name "librt.a" \
        -not -name "libdl.a" \
        -not -name "libresolv.a" \
        -not -name "libutil.a" \
        -not -name "libcrypt.a" \
        -delete 2>/dev/null || true

    # Strip debugging symbols from shared libraries
    find "$root" -type f -name "*.so*" -exec strip --strip-unneeded {} + 2>/dev/null || true
    find "$root" -type f -name "*.dylib" -exec strip -x {} + 2>/dev/null || true
}

pack_tarball() {
    local src_dir="$1"
    local out_tar="$2"
    mkdir -p "$(dirname "$out_tar")"

    log "Compressing $src_dir -> $out_tar ..."
    # Deterministic tar with xz high compression
    XZ_OPT="-9e -T0" tar -C "$src_dir" -cJf "$out_tar" .
    log_step "Created $out_tar ($(du -h "$out_tar" | cut -f1))"
}

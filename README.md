# Target SDK Sysroots for hyprcross

[![Build & Release](https://github.com/runepm/sdks/actions/workflows/build-sdks.yml/badge.svg)](https://github.com/runepm/sdks/actions/workflows/build-sdks.yml)
[![License: MIT OR Apache-2.0](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](LICENSE-MIT.md)

This repository contains the build automation, packaging scripts, and release definitions for all cross-compilation target SDKs and sysroots used by [hyprcross](https://github.com/runepm/hyprcross) and [Rune](https://github.com/runepm/rune).

## Overview

Unlike traditional cross-compilation systems that force users to run full container engines (Docker/Podman) downloading 500 MB – 1 GB images, **hyprcross** downloads lightweight, pre-extracted target SDK sysroots (typically 12–28 MB) and links directly on the host using **hyprlnk**.

These SDKs contain:
- C/C++ target headers (`/usr/include`)
- Dynamic link stubs and runtime libraries (`/usr/lib`, `libc.so`, `libc.a`, `crt*.o`)
- Import libraries for Windows (`.lib`, `.dll.a`)
- Mach-O Darwin SDK definitions for Apple targets

## Supported Targets

### Linux (glibc)
- `x86_64-unknown-linux-gnu`
- `i686-unknown-linux-gnu`
- `aarch64-unknown-linux-gnu`
- `armv7-unknown-linux-gnueabihf`
- `arm-unknown-linux-gnueabi`
- `riscv64gc-unknown-linux-gnu`
- `powerpc64le-unknown-linux-gnu`
- `powerpc64-unknown-linux-gnu`
- `powerpc-unknown-linux-gnu`
- `s390x-unknown-linux-gnu`
- `sparc64-unknown-linux-gnu`
- `loongarch64-unknown-linux-gnu`

### Linux (musl)
- `x86_64-unknown-linux-musl`
- `i686-unknown-linux-musl`
- `aarch64-unknown-linux-musl`
- `armv7-unknown-linux-musleabihf`
- `arm-unknown-linux-musleabihf`
- `riscv64gc-unknown-linux-musl`
- `powerpc64le-unknown-linux-musl`

### Windows (MSVC & MinGW)
- `x86_64-pc-windows-msvc`
- `aarch64-pc-windows-msvc`
- `i686-pc-windows-msvc`
- `x86_64-pc-windows-gnu`
- `i686-pc-windows-gnu`
- `x86_64-pc-windows-gnullvm`
- `aarch64-pc-windows-gnullvm`

### Android (NDK)
- `aarch64-linux-android`
- `armv7-linux-androideabi`
- `x86_64-linux-android`
- `i686-linux-android`

### BSD & Apple
- `x86_64-unknown-freebsd`
- `aarch64-apple-darwin` / `x86_64-apple-darwin` (`MacOSX.sdk`)

## Local Building

To build a specific target SDK locally:

```bash
./builders/build-target.sh <target-triple> dist/
```

Example:
```bash
./builders/build-target.sh aarch64-unknown-linux-gnu dist/
```

## GitHub Release Structure

Releases are published at:
`https://github.com/runepm/sdks/releases/download/<version>/<target-triple>.tar.xz`

hyprcross fetches these automatically on first build or via:
```console
$ hyprcross sdk install <target-triple>
```

# Contributing to hyprcross SDKs

Thank you for your interest in contributing to the hyprcross SDK & Sysroot repository!

## Target Sysroot Principles

1. **Lightweight & Linking-Focused**: Sysroots should contain the minimum necessary files for compiling C/C++ dependencies and linking target binaries (headers, import libraries, libc, crt objects). Documentation, man pages, and unnecessary static libraries are pruned.
2. **Deterministic & Compressed**: SDK tarballs are compressed with `.tar.xz` (`-9e -T0`) for fast downloads.
3. **No Container Daemon Requirement**: hyprcross downloads and extracts these tarballs directly onto host systems for zero-Docker cross compilation.

## Adding or Updating a Target

1. Builders are located in `builders/`:
   - `build-linux-gnu.sh` (glibc targets)
   - `build-linux-musl.sh` (musl targets)
   - `build-windows-gnu.sh` (MinGW targets)
   - `build-windows-msvc.sh` (MSVC stubs / xwin)
   - `build-android.sh` (Android NDK)
   - `build-freebsd.sh` (FreeBSD sets)
2. Add your target to the router script `builders/build-target.sh`.
3. Test locally:
   ```bash
   ./builders/build-target.sh <target-triple> dist/
   ```
4. Verify the tarball layout:
   ```bash
   tar -tvf dist/<target-triple>.tar.xz | head -n 30
   ```

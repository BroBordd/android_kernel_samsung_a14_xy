#!/bin/bash
# Galaxy A14 (exynos850-a14nsxx) kernel build: toolchain + KernelSU bootstrap, then incremental build.
set -e
cd "$(dirname "$(readlink -f "$0")")"
ROOT=$(pwd)

CLANG_DIR="$ROOT/toolchain/clang/host/linux-x86/clang-r450784e"
CLANG_URL="https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/clang-r450784e.tar.gz"
DEFCONFIG="exynos850-a14nsxx_defconfig"
DEFCONFIG_FILE="arch/arm64/configs/$DEFCONFIG"

# 0. Host dependency: pahole (dwarves) is needed for BTF generation
if ! command -v pahole >/dev/null 2>&1; then
    echo "[+] pahole missing, installing dwarves..."
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    $SUDO apt-get update -y && $SUDO apt-get install -y dwarves
fi

# 1. Toolchain
if [ ! -x "$CLANG_DIR/bin/clang" ]; then
    echo "[+] Toolchain missing, downloading clang-r450784e..."
    mkdir -p "$CLANG_DIR"
    curl -L --fail "$CLANG_URL" | tar -xz -C "$CLANG_DIR"
fi

# 2. KernelSU-Next
if [ ! -e KernelSU-Next/kernel/Kconfig ] || [ "$(readlink drivers/kernelsu 2>/dev/null)" != "../KernelSU-Next/kernel" ]; then
    echo "[+] KernelSU-Next missing, setting up..."
    rm -rf KernelSU            # remove old upstream KernelSU if present
    rm -f drivers/kernelsu     # drop old symlink so setup relinks cleanly
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/dev/kernel/setup.sh" | bash -s -
fi
if ! grep -q '^CONFIG_KSU=y' "$DEFCONFIG_FILE"; then
    echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
    rm -f .config   # force regeneration with KSU enabled
fi

# 3. Build (incremental: no clean, .config only generated if missing)
export PATH="$CLANG_DIR/bin:$PATH"
export DTC_FLAGS="-@"
export PLATFORM_VERSION=14
export ANDROID_MAJOR_VERSION=u
export LLVM=1
export DEPMOD=depmod
export ARCH=arm64
export TARGET_SOC=s5e3830

[ -f .config ] || make "$DEFCONFIG"
make -j"$(nproc)" 2>&1 | tee build.log
echo "[+] Done: arch/arm64/boot/Image"

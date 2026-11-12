#!/bin/bash
# Galaxy A14: bootstrap deps + KernelSU-Next, then run the repo's packaging build (makes boot/vendor_boot + zip + tar).
set -e
cd "$(dirname "$(readlink -f "$0")")"

# 0. Host dependencies
need=""
for t in pahole brotli zip lz4 cpio zstd bc bison flex python3; do
    command -v "$t" >/dev/null 2>&1 || need="$need $t"
done
if [ -n "$need" ]; then
    echo "[+] Installing missing tools:$need"
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    $SUDO apt-get update -y
    $SUDO apt-get install -y dwarves brotli zip lz4 cpio zstd bc bison flex python3 libssl-dev libelf-dev xz-utils
fi

# 1. KernelSU-Next
if [ ! -e KernelSU-Next/kernel/Kconfig ] || [ "$(readlink drivers/kernelsu 2>/dev/null)" != "../KernelSU-Next/kernel" ]; then
    echo "[+] KernelSU-Next missing, setting up..."
    rm -rf KernelSU
    rm -f drivers/kernelsu
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/dev/kernel/setup.sh" | bash -s -
fi
grep -q '^CONFIG_KSU=y' arch/arm64/configs/a14_defconfig || echo "CONFIG_KSU=y" >> arch/arm64/configs/a14_defconfig

# 2. Build + package (toolchain is fetched by kernel_build/build.sh if missing; build is incremental in out/)
./kernel_build/build.sh "$(pwd)"
echo "[+] Output: kernel_build/ExynosUnbound-*_a14.zip and .tar"

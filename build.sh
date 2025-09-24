#!/bin/bash
#
# Hydrogen Kernel build script
#

# Exit immediately if a command exits with a non-zero status.
set -e

# Initial Setup
SECONDS=0
DATE=$(date '+%Y%m%d-%H%M')

DEVICE="pissarro"
DEFCONFIG="${DEVICE}_defconfig"
ZIPNAME="HydrogenKernel-${DEVICE}-${DATE}.zip"
CURRENT_DIR=$(pwd)

echo -e "Building for device: $DEVICE\n"

# Toolchain Setup
TC_DIR="$HOME/toolchains/neutron-clang"
if [ ! -d "$TC_DIR" ]; then
    echo "Toolchain not found, downloading neutron-clang..."
    mkdir -p "$TC_DIR"
    (cd "$TC_DIR" && bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S=05012024)
fi
export PATH="$TC_DIR/bin:$PATH"

# Option Handling
CLEAN_BUILD=false
# Check for a argument for cleaning
if [[ "$1" == "-c" || "$1" == "clean" ]]; then
    CLEAN_BUILD=true
fi

# If the -c flag is specified, perform a full clean
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "Performing a full clean...\n"
    rm -rf out
fi

# Compilation Variables
export ARCH=arm64
export SUBARCH=arm64

# Optimizations for Neutron Clang
export KBUILD_GLOBAL_CFLAGS="-O3 -flto=thin"
export KBUILD_GLOBAL_CPPFLAGS="-O3 -flto=thin"

# Apply defconfig
make O=out "$DEFCONFIG"

echo -e "\nStarting kernel compilation...\n"

# Start the build for Image.gz and dtbo.img
if make -j$(nproc --all) \
    O=out \
    CC="ccache clang" \
    AR=llvm-ar \
    NM=llvm-nm \
    LD=ld.lld \
    STRIP=llvm-strip \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    Image.gz; then

    echo -e "\nKernel compiled successfully! Packing into a zip archive...\n"

    # Cloning AnyKernel3
    git clone -q --depth=1 https://github.com/Z3roKwq/AnyKernel3 AnyKernel3

    # Copying the compiled images
    cp out/arch/arm64/boot/Image.gz AnyKernel3/

    # Creating the zip archive
    (cd AnyKernel3 && zip -r9 "../$ZIPNAME" ./* -x '*.git*' README.md '*placeholder')

    # Cleanup
    rm -rf AnyKernel3

    echo -e "\nFinished in $((SECONDS / 60)) min(s) and $((SECONDS % 60)) sec(s)!"
    echo "Kernel installer zip: $ZIPNAME"
else
    echo -e "\nBuild failed!"
    exit 1
fi
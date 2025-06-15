#!/bin/bash

set -e

LTO=full

# download toolchain from https://opensource.samsung.com/uploadSearch?searchValue=toolchain 
TOOLCHAIN=$(realpath "/home/kokuban/PlentyofToolchain/toolchainS25/kernel_platform/prebuilts")

export PATH=$TOOLCHAIN/build-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/build-tools/path/linux-x86:$PATH
export PATH=$TOOLCHAIN/clang/host/linux-x86/clang-r510928/bin:$PATH
export PATH=$TOOLCHAIN/clang-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/kernel-build-tools/linux-x86/bin:$PATH

LLD_COMPILER_RT="-fuse-ld=lld --rtlib=compiler-rt"

sysroot_flags+="--sysroot=$TOOLCHAIN/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot "

cflags+="-I$TOOLCHAIN/kernel-build-tools/linux-x86/include "
ldflags+="-L $TOOLCHAIN/kernel-build-tools/linux-x86/lib64 "
ldflags+=${LLD_COMPILER_RT}

export LD_LIBRARY_PATH="$TOOLCHAIN/kernel-build-tools/linux-x86/lib64"
export HOSTCFLAGS="$sysroot_flags $cflags"
export HOSTLDFLAGS="$sysroot_flags $ldflags"
TARGET_DEFCONFIG=${1:-sun_gki_defconfig}

cd "$(dirname "$0")"

echo "-android15-Kokuban-Herta-AYDA-SukiSUU-g$(git rev-parse --short HEAD)" > ./localversion

ARGS="
CC=clang
ARCH=arm64
LLVM=1 LLVM_IAS=1
"

# build kernel
make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS} $TARGET_DEFCONFIG

./scripts/config --file out/.config \
  -d UH \
  -d RKP \
  -d KDP \
  -d SECURITY_DEFEX \
  -d INTEGRITY \
  -d FIVE \
  -d TRIM_UNUSED_KSYMS \
  -d PROCA \
  -d PROCA_GKI_10 \
  -d PROCA_S_OS \
  -d PROCA_CERTIFICATES_XATTR \
  -d PROCA_CERT_ENG \
  -d PROCA_CERT_USER \
  -d GAF \
  -d GAF_V6 \
  -d FIVE \
  -d FIVE_CERT_USER \
  -d FIVE_DEFAULT_HASH

if [ "$LTO" = "thin" ]; then
  ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS}

echo -n > ./localversion

cd out
if [ ! -d AnyKernel3 ]; then
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b sun
fi
cp arch/arm64/boot/Image AnyKernel3/Image
cd AnyKernel3
chmod +x ./patch_linux
./patch_linux
mv oImage zImage
rm -f oImage
rm -f Image
rm -f patch_linux
cd ..
name=S25_kernel_`cat include/config/kernel.release`_`date '+%Y_%m_%d'`
cd AnyKernel3
zip -r ${name}.zip * -x *.zip
cd ..
cp AnyKernel3/zImage AnyKernel3/tools/kernel
cd AnyKernel3/tools
chmod +x libmagiskboot.so
lz4 boot.img.lz4
./libmagiskboot.so repack boot.img ${name}.img 
echo "boot.img output to $(realpath $name).img"
cd ..
cd ..
echo "AnyKernel3 package output to $(realpath $name).zip"


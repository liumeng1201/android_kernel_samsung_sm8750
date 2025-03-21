export PATH="/home/kokuban/toolchainS25/kernel_platform/prebuilts/clang/host/linux-x86/clang-r510928/bin:usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:$PATH"

echo $PATH

set -e

TARGET_DEFCONFIG=${1:-inline_sun_gki_defconfig}

cd "$(dirname "$0")"

if [ "$LTO" == "thin" ]; then
  LOCALVERSION+="-thin"
fi

ARGS="
CC=clang
ARCH=arm64
LLVM=1 LLVM_IAS=1
LOCALVERSION=$LOCALVERSION
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
  -d GAF_V6 \
  -d FIVE \
  -d FIVE_CERT_USER \
  -d FIVE_DEFAULT_HASH

if [ "$LTO" = "thin" ]; then
  ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS}

cd out
if [ ! -d AnyKernel3 ]; then
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b sun
fi
rm -rf AnyKernel3/modules
cp arch/arm64/boot/Image AnyKernel3/zImage
sed -i '9s/.*/do.modules=0/' AnyKernel3/anykernel.sh
name=S25_${TARGET_DEFCONFIG%%_defconfig}_kernel_`cat include/config/kernel.release`_`date '+%Y_%m_%d'`
cd AnyKernel3
zip -r ${name}.zip * -x *.zip
echo "AnyKernel3 package output to $(realpath $name).zip"

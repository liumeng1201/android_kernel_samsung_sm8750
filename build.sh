export PATH="/home/kokuban/android_kernel_samsung_sm8750/clang/host/linux-x86/clang-r510928/bin:usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:$PATH"

echo $PATH

set -e

TARGET_DEFCONFIG=${1:-sun_gki_defconfig}

cd "$(dirname "$0")"

LOCALVERSION=-Kokuban-android15-8-Herta-30455426-abogkiS938BXXU1AYA1

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
  -d TRIM_UNUSED_KSYMS

if [ "$LTO" = "thin" ]; then
  ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS}

cd out
if [ ! -d AnyKernel3 ]; then
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b sun
fi
DEST_DIR_1="AnyKernel3/modules/vendor_dlkm/lib/modules"
# 查找所有 .ko 文件并复制
find . -type f -name "*.ko" -exec cp {} $DEST_DIR_1 \;
rm -f AnyKernel3/modules/vendor_dlkm/lib/modules/placeholder
echo "所有 .ko 文件已成功复制到目标目录。"
cp arch/arm64/boot/Image AnyKernel3/zImage
name=${TARGET_DEFCONFIG%%_defconfig}_kernel_`cat include/config/kernel.release`_`date '+%Y_%m_%d'`
cd AnyKernel3
zip -r ${name}.zip * -x *.zip
echo "AnyKernel3 package output to $(realpath $name).zip"
cd ..
git clone --depth=1 https://github.com/YuzakiKokuban/S25_Kernel_ko_installer.git
cp -rf AnyKernel3/modules/vendor_dlkm/lib/modules S25_Kernel_ko_installer/
name2=S25_Kernel_ko_installer_$name
cd S25_Kernel_ko_installer
zip -r ${name2}.zip * -x *.zip
echo "S25_Kernel_ko_installer package output to $(realpath $name2).zip"

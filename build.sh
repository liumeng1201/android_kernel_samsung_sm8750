#!/usr/bin/env bash

# 脚本出错时立即退出
set -e

# --- 用户配置 ---

# 1. 主配置文件
# 这是你的 S25 内核的基础配置
MAIN_DEFCONFIG=sun_gki_defconfig

# 2. 内核版本标识
# git commit hash 会自动附加
LOCALVERSION_BASE=-android15-Kokuban-Herta-AYDA-SukiSUU

# 3. LTO (Link Time Optimization)
# 设置为 "thin" 或 "" (留空以禁用)。注意：新脚本似乎不支持 'full'。
LTO="full"

# 4. 工具链路径
# 指向你的 S25 新工具链的 'prebuilts' 目录
TOOLCHAIN_DIR=$(realpath "/home/kokuban/PlentyofToolchain/toolchainS25/kernel_platform/prebuilts")

# --- 脚本开始 ---

# 切换到脚本所在目录 (内核源码根目录)
cd "$(dirname "$0")"

# --- 环境和路径设置 (来自 S25 脚本) ---
echo "--- 正在设置 S25 工具链环境 ---"
export PATH="$TOOLCHAIN_DIR/build-tools/linux-x86/bin:$PATH"
export PATH="$TOOLCHAIN_DIR/build-tools/path/linux-x86:$PATH"
export PATH="$TOOLCHAIN_DIR/clang/host/linux-x86/clang-r510928/bin:$PATH"
export PATH="$TOOLCHAIN_DIR/clang-tools/linux-x86/bin:$PATH"
export PATH="$TOOLCHAIN_DIR/kernel-build-tools/linux-x86/bin:$PATH"

# 设置编译和链接器标志
LLD_COMPILER_RT="-fuse-ld=lld --rtlib=compiler-rt"
SYSROOT_FLAGS="--sysroot=$TOOLCHAIN_DIR/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot"
CFLAGS="-I$TOOLCHAIN_DIR/kernel-build-tools/linux-x86/include"
LDFLAGS="-L $TOOLCHAIN_DIR/kernel-build-tools/linux-x86/lib64 ${LLD_COMPILER_RT}"

export LD_LIBRARY_PATH="$TOOLCHAIN_DIR/kernel-build-tools/linux-x86/lib64"
export HOSTCFLAGS="$SYSROOT_FLAGS $CFLAGS"
export HOSTLDFLAGS="$SYSROOT_FLAGS $LDFLAGS"
export KBUILD_BUILD_USER="Kokuban"
export KBUILD_BUILD_HOST="Kokuban-PC"

# =============================== 核心编译参数 ===============================
# 使用 S25 内核所需的 LLVM 参数
MAKE_ARGS="
O=out
ARCH=arm64
CC=clang
LLVM=1
LLVM_IAS=1
"
# ======================================================================

# 1. 清理旧的编译产物 (好习惯，予以保留)
echo "--- 正在清理 (rm -rf out) ---"
rm -rf out

# 2. 应用 defconfig
echo "--- 正在应用 defconfig: $MAIN_DEFCONFIG ---"
make ${MAKE_ARGS} $MAIN_DEFCONFIG
if [ $? -ne 0 ]; then
    echo "错误: 应用 defconfig 失败。"
    exit 1
fi

# 3. 后处理配置 (OneUI 内核编译的关键步骤)
echo "--- 正在禁用三星安全特性 (RKP, KDP, etc.) ---"
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

# 4. 配置 LTO (如果已启用)
if [ "$LTO" == "thin" ]; then
    echo "--- 正在启用 ThinLTO ---"
    ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

# 5. 写入 localversion 文件
# S25 脚本通过文件传递版本号
echo "--- 正在写入版本号 ---"
echo "${LOCALVERSION_BASE}-g$(git rev-parse --short HEAD)" > ./localversion

# 6. 开始编译内核
echo "--- 开始编译内核 (-j$(nproc)) ---"
make -j$(nproc) ${MAKE_ARGS} 2>&1 | tee kernel_build_log.txt
BUILD_STATUS=${PIPESTATUS[0]}

# 编译后清理 localversion 文件
echo -n > ./localversion

if [ $BUILD_STATUS -ne 0 ]; then
    echo "--- 内核编译失败！ ---"
    echo "请检查 'kernel_build_log.txt' 文件以获取更多错误信息。"
    exit 1
fi

echo -e "\n--- 内核编译成功！ ---\n"

# 7. 打包 AnyKernel3 Zip 和 boot.img
echo "--- 正在打包 AnyKernel3 Zip 和 boot.img ---"
cd out
if [ ! -d AnyKernel3 ]; then
  # 注意：这里的 -b sun 分支是根据你的 S25 脚本来的
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b sun AnyKernel3
fi

cp arch/arm64/boot/Image AnyKernel3/Image

cd AnyKernel3
chmod +x ./patch_linux
./patch_linux
mv oImage zImage
rm -f oImage Image patch_linux

kernel_release=$(cat ../include/config/kernel.release)
zip_name="S25_kernel_${kernel_release}_$(date '+%Y%m%d')"

echo "--- 正在创建 Zip 刷机包 ---"
zip -r9 "../${zip_name}.zip" . -x "*.zip"

echo "--- 正在创建 boot.img ---"
cp zImage tools/kernel
cd tools
chmod +x libmagiskboot.so
# 确保 lz4 工具可用
if ! command -v lz4 &> /dev/null; then
    echo "错误: 未找到 'lz4' 命令。请先安装 lz4。"
    exit 1
fi
lz4 boot.img.lz4
./libmagiskboot.so repack boot.img
mv boot.img "../../../${zip_name}.img"
cd ../.. # 返回到 out 目录

echo "======================================================"
echo "成功！"
echo "刷机包输出到: $(realpath ${zip_name}.zip)"
echo "Boot 镜像输出到: $(realpath ${zip_name}.img)"
echo "======================================================"

exit 0

    #!/usr/bin/env bash

# 脚本出错时立即退出
set -e

# --- 用户配置 (S25) ---

# 1. 主配置文件
# S25 内核的基础配置
MAIN_DEFCONFIG=sun_gki_defconfig

# 2. 内核版本标识
# git commit hash 会自动附加
LOCALVERSION_BASE=-android15-Kokuban-Herta-AYF1-SukiSUU

# 3. LTO (Link Time Optimization)
# 设置为 "full", "thin" 或 "" (留空以禁用)
LTO=""

# 4. 工具链路径
# 指向你的 S25 新工具链的 'prebuilts' 目录
TOOLCHAIN=$(realpath "./toolchain/toolchainS25/kernel_platform/prebuilts")

# 5. AnyKernel3 打包配置
ANYKERNEL_REPO="https://github.com/YuzakiKokuban/AnyKernel3.git"
ANYKERNEL_BRANCH="sun"

# 6. 输出文件名前缀
ZIP_NAME_PREFIX="S25_kernel"

# --- 脚本开始 ---

# 切换到脚本所在目录 (内核源码根目录)
cd "$(dirname "$0")"

# --- 环境和路径设置 (S25) ---
echo "--- 正在设置 S25 工具链环境 ---"
export PATH=$TOOLCHAIN/build-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/build-tools/path/linux-x86:$PATH
export PATH=$TOOLCHAIN/clang/host/linux-x86/clang-r510928/bin:$PATH
export PATH=$TOOLCHAIN/clang-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/kernel-build-tools/linux-x86/bin:$PATH

# 设置编译和链接器标志
LLD_COMPILER_RT="-fuse-ld=lld --rtlib=compiler-rt"

sysroot_flags+="--sysroot=$TOOLCHAIN/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot "

cflags+="-I$TOOLCHAIN/kernel-build-tools/linux-x86/include "
ldflags+="-L $TOOLCHAIN/kernel-build-tools/linux-x86/lib64 "
ldflags+=${LLD_COMPILER_RT}

export LD_LIBRARY_PATH="$TOOLCHAIN/kernel-build-tools/linux-x86/lib64"
export HOSTCFLAGS="$sysroot_flags $cflags"
export HOSTLDFLAGS="$sysroot_flags $ldflags"

# =============================== 核心编译参数 ===============================
MAKE_ARGS="
O=out
ARCH=arm64
CC=clang
LLVM=1
LLVM_IAS=1
"
# ======================================================================

# 1. 清理旧的编译产物
echo "--- 正在清理 (rm -rf out) ---"
rm -rf out

# 2. 应用 defconfig
echo "--- 正在应用 defconfig: $MAIN_DEFCONFIG ---"
make ${MAKE_ARGS} $MAIN_DEFCONFIG
if [ $? -ne 0 ]; then
    echo "错误: 应用 defconfig '$MAIN_DEFCONFIG' 失败。"
    exit 1
fi

# 3. 后处理配置 (禁用三星安全特性)
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
  -d FIVE_CERT_USER \
  -d FIVE_DEFAULT_HASH

# 4. 配置 LTO (Link Time Optimization)
if [ "$LTO" == "full" ]; then
    echo "--- 正在启用 FullLTO ---"
    ./scripts/config --file out/.config -e LTO_CLANG_FULL -d LTO_CLANG_THIN
elif [ "$LTO" == "thin" ]; then
    echo "--- 正在启用 ThinLTO ---"
    ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
else
    echo "--- LTO 已禁用 ---"
    ./scripts/config --file out/.config -d LTO_CLANG_FULL -d LTO_CLANG_THIN
fi

# 5. 写入 localversion 文件
version_string="${LOCALVERSION_BASE}-g$(git rev-parse --short HEAD)"
echo "--- 正在写入版本号: ${version_string} ---"
echo "${version_string}" > ./localversion

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
echo "--- 正在准备打包环境 ---"
cd out

if [ ! -d AnyKernel3 ]; then
  echo "--- 正在克隆 AnyKernel3 仓库 (分支: ${ANYKERNEL_BRANCH}) ---"
  git clone --depth=1 "${ANYKERNEL_REPO}" -b "${ANYKERNEL_BRANCH}" AnyKernel3
fi

# 复制原始内核镜像，准备 patch
cp arch/arm64/boot/Image AnyKernel3/Image

cd AnyKernel3

# 运行 patch_linux 脚本
echo "--- 正在运行 patch_linux ---"
chmod +x ./patch_linux
./patch_linux
# patch_linux 脚本会生成 oImage, 我们将其重命名为 AnyKernel3 所需的 zImage
mv oImage zImage
# 清理中间文件
rm -f Image oImage patch_linux
echo "--- patch_linux 执行完毕, 已生成 zImage ---"

# 检查 lz4 命令是否存在
if ! command -v lz4 &> /dev/null; then
    echo "错误: 未找到 'lz4' 命令。请先安装 lz4 工具。"
    exit 1
fi

# 检查 boot.img 打包工具的完整性
if [ ! -f "tools/libmagiskboot.so" ] || [ ! -f "tools/boot.img.lz4" ]; then
    echo "错误: boot.img 打包工具不完整！请检查你的 AnyKernel3 仓库。"
    exit 1
fi

# 准备输出文件名
kernel_release=$(cat ../include/config/kernel.release)
final_name="${ZIP_NAME_PREFIX}_${kernel_release}_$(date '+%Y%m%d')"

echo "--- 正在创建 Zip 刷机包: ${final_name}.zip ---"
zip -r9 "../${final_name}.zip" . -x "*.zip"

echo "--- 正在创建 boot.img: ${final_name}.img ---"
# 复制最终的 zImage 用于制作 boot.img
cp zImage tools/kernel
cd tools
chmod +x libmagiskboot.so
lz4 boot.img.lz4
./libmagiskboot.so repack boot.img
mv new-boot.img "../../${final_name}.img"
cd ../.. # 返回到 out 目录

echo "======================================================"
echo "成功！"
echo "刷机包输出到: $(realpath ${final_name}.zip)"
echo "Boot 镜像输出到: $(realpath ${final_name}.img)"
echo "======================================================"

exit 0

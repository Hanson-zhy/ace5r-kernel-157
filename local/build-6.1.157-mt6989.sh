#!/bin/bash
# 一加Ace5竞速版 (MT6989) 6.1.157 OKI内核本地构建脚本
# 需 x86_64 Ubuntu 22.04/24.04 (Clang20工具链为x86_64宿主)
# 用法: KSU_TYPE=ksunext bash build-6.1.157-mt6989.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 配置(环境变量可覆盖) =====
KSU_TYPE=${KSU_TYPE:-ksunext}          # ksunext / sukisu / ksu / none
APPLY_SUSFS=${APPLY_SUSFS:-y}
APPLY_LZ4=${APPLY_LZ4:-y}
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
APPLY_BBR=${APPLY_BBR:-n}              # n / y / d
APPLY_SSG=${APPLY_SSG:-y}
APPLY_BBG=${APPLY_BBG:-y}
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android14-11-o-gc2dad16af736}

echo "===== MT6989 Ace5竞速版 6.1.157 本地构建 ====="
echo "KSU: $KSU_TYPE | SUSFS: $APPLY_SUSFS | LZ4/ZSTD: $APPLY_LZ4"
echo "BetterNet: $APPLY_BETTERNET | BBR: $APPLY_BBR | SSG: $APPLY_SSG | BBG: $APPLY_BBG"
echo "后缀: -$CUSTOM_SUFFIX"

# ===== 依赖 =====
if command -v apt-get >/dev/null; then
  sudo apt-get update -qq || true
  sudo apt-get install -y --no-install-recommends curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev cpio xz-utils tar unzip aria2 zstd
fi

# ===== 工作区 =====
mkdir -p kernel_workspace
cd kernel_workspace

# ===== 下载源码(精确SHA固定) =====
if [ ! -d common ]; then
  echo ">>> 下载 6.1.157 官方源码 (SHA固定: 822beed4)..."
  aria2c -s16 -x16 -k1M https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989/archive/822beed40827f1e9a103bc06ab4714a670080b72.tar.gz -o common.tar.gz
  tar -xf common.tar.gz
  mv android_kernel_oneplus_mt6989-822beed40827f1e9a103bc06ab4714a670080b72 common
  rm -f common.tar.gz
fi
if [ ! -d ref134 ]; then
  echo ">>> 下载 cctv18 6.1.134 参考树 (SSG来源, SHA固定: 16bc5565)..."
  aria2c -s16 -x16 -k1M https://github.com/cctv18/android_kernel_oneplus_mt6989/archive/16bc556523df15b47f47ec4185616f0304c44240.tar.gz -o ref134.tar.gz
  mkdir -p ref134
  tar -xf ref134.tar.gz -C ref134 --strip-components=1
  rm -f ref134.tar.gz
fi
if [ ! -d clang20 ]; then
  echo ">>> 下载 LLVM-Clang20 r547379 工具链..."
  aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang20-r547379/clang-r547379.zip -o clang.zip
  mkdir -p clang20 && unzip -q clang.zip -d clang20 && rm -f clang.zip
fi
if [ ! -d build-tools ]; then
  echo ">>> 下载 build-tools..."
  aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang20-r547379/build-tools.zip
  unzip -q build-tools.zip && rm -f build-tools.zip
fi

# ===== ABI清理 + dirty后缀 =====
rm -f common/android/abi_gki_protected_exports_*
for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done

# ===== SSG移植(134 -> 157) =====
if [[ "$APPLY_SSG" == [yY] ]]; then
  echo ">>> 移植SSG IO调度器..."
  cp -n ref134/block/ssg-iosched.c ref134/block/ssg-stat.c ref134/block/ssg-cgroup.c ref134/block/ssg.h common/block/
  grep -q "MQ_IOSCHED_SSG" common/block/Makefile || cat >> common/block/Makefile << 'MAKEEOF'

ssg-$(CONFIG_MQ_IOSCHED_SSG) := ssg-iosched.o ssg-stat.o
ssg-$(CONFIG_MQ_IOSCHED_SSG_CGROUP) += ssg-cgroup.o
obj-$(CONFIG_MQ_IOSCHED_SSG) += ssg.o
MAKEEOF
  grep -q "MQ_IOSCHED_SSG" common/block/Kconfig.iosched || cat >> common/block/Kconfig.iosched << 'KCEOF'

config MQ_IOSCHED_SSG
	tristate "SamSung Generic I/O scheduler"
	default n
	help
	  SamSung Generic IO scheduler.

config MQ_IOSCHED_SSG_CGROUP
	tristate "Control Group for SamSung Generic I/O scheduler"
	default n
	depends on BLK_CGROUP
	depends on MQ_IOSCHED_SSG
	help
	  Control Group for SamSung Generic I/O scheduler.
KCEOF
fi

# ===== KernelSU =====
if [[ "$KSU_TYPE" == "ksunext" ]]; then
  echo ">>> KernelSU Next (dev-susfs)..."
  [ -d KernelSU-Next ] || curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd KernelSU-Next && rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000 2>/dev/null || echo 114514)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s//"//' || echo "v1.0.0")
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := ${KSU_GIT_TAG:-v1.0.0}/g" kernel/Kbuild
  cd ../common/drivers/kernelsu
  [ -f apk_sign.patch ] || { wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/other_patch/apk_sign.patch; patch -p2 -N -F 3 < apk_sign.patch || true; }
  cd ../../..
elif [[ "$KSU_TYPE" == "sukisu" ]]; then
  echo ">>> ReSukiSU..."
  [ -d KernelSU ] || curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/refs/heads/main/kernel/setup.sh" | bash -s main
elif [[ "$KSU_TYPE" == "ksu" ]]; then
  echo ">>> 原版KernelSU..."
  [ -d KernelSU ] || curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000 2>/dev/null || echo 114514)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
  cd ..
else
  echo ">>> 无内置KSU"
fi

# ===== SUSFS =====
if [[ "$APPLY_SUSFS" == [yY] && "$KSU_TYPE" != "none" ]]; then
  echo ">>> SUSFS补丁..."
  [ -d susfs4ksu ] || git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu -b oki-android14-6.1
  wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd common
  grep -q "CONFIG_KSU_SUSFS" arch/arm64/configs/gki_defconfig || {
    patch -p1 -F 3 < 50_add_susfs_in_gki-android14-6.1.patch || true
    patch -p1 -N -F 3 < 69_hide_stuff.patch || true
  }
  cd ..
fi

# ===== LZ4/ZSTD =====
if [[ "$APPLY_LZ4" == [yY] ]]; then
  echo ">>> lz4 1.10.0 & zstd 1.5.7..."
  wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/zram_patch/001-lz4.patch -O ./common/001-lz4.patch
  wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/zram_patch/lz4armv8.S -O ./common/lib/lz4armv8.S
  wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/zram_patch/002-zstd.patch -O ./common/002-zstd.patch
  cd common
  patch -p1 -F 3 < 001-lz4.patch || true
  patch -p1 -F 3 < 002-zstd.patch || true
  cd ..
fi

# ===== CVE修复 =====
cd common
wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/other_patch/cve-2026-43499-rtmutex-6.1.patch
patch -p1 -F 3 < cve-2026-43499-rtmutex-6.1.patch || true
cd ..

# ===== defconfig =====
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig
[[ "$KSU_TYPE" != "none" ]] && echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] && "$KSU_TYPE" != "none" ]]; then
  grep -q "CONFIG_KSU_SUSFS=y" "$DEFCONFIG_FILE" || cat >> "$DEFCONFIG_FILE" << 'EOF'
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
EOF
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

if [[ "$APPLY_BETTERNET" == [yY] ]]; then
  cat >> "$DEFCONFIG_FILE" << 'EOF'
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_IP_SET=y
CONFIG_IP_SET_MAX=65534
CONFIG_IP_SET_BITMAP_IP=y
CONFIG_IP_SET_BITMAP_IPMAC=y
CONFIG_IP_SET_BITMAP_PORT=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_IPMARK=y
CONFIG_IP_SET_HASH_IPPORT=y
CONFIG_IP_SET_HASH_IPPORTIP=y
CONFIG_IP_SET_HASH_IPPORTNET=y
CONFIG_IP_SET_HASH_MAC=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_IP_SET_HASH_NETNET=y
CONFIG_IP_SET_HASH_NETPORT=y
CONFIG_IP_SET_HASH_NETIFACE=y
CONFIG_IP_SET_LIST_SET=y
CONFIG_IP6_NF_NAT=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y
EOF
  cd common
  wget -q https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

if [[ "$APPLY_BBR" == [yYdD] ]]; then
  cat >> "$DEFCONFIG_FILE" << 'EOF'
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_TCP_CONG_VEGAS=y
CONFIG_TCP_CONG_NV=y
CONFIG_TCP_CONG_WESTWOOD=y
CONFIG_TCP_CONG_HTCP=y
CONFIG_TCP_CONG_BRUTAL=y
EOF
  if [[ "$APPLY_BBR" == [dD] ]]; then
    echo 'CONFIG_DEFAULT_TCP_CONG="bbr"' >> "$DEFCONFIG_FILE"
  else
    echo 'CONFIG_DEFAULT_TCP_CONG="cubic"' >> "$DEFCONFIG_FILE"
  fi
fi

if [[ "$APPLY_SSG" == [yY] ]]; then
  echo "CONFIG_MQ_IOSCHED_SSG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_SSG_CGROUP=y" >> "$DEFCONFIG_FILE"
fi

if [[ "$APPLY_BBG" == [yY] ]]; then
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd common
  [ -d Baseband-guard ] || curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

sed -i 's/check_defconfig//' ./common/build.config.gki || true

# ===== 编译 =====
echo ">>> 编译..."
export PATH="$PWD/clang20/bin:$PATH"
export PATH="$PWD/build-tools/bin:$PATH"
cd common
make -j$(nproc) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LD=ld.lld HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error gki_defconfig
make -j$(nproc) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LD=ld.lld HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error Image
echo ">>> 编译完成: $PWD/out/arch/arm64/boot/Image"

# ===== AnyKernel3打包 =====
cd ..
[ -d AnyKernel3 ] || git clone --depth=1 https://github.com/cctv18/AnyKernel3
rm -rf ./AnyKernel3/.git
cp common/out/arch/arm64/boot/Image AnyKernel3/
cd AnyKernel3
ZIP_NAME="AnyKernel3_MT6989_6.1.157_${KSU_TYPE}"
[[ "$APPLY_SUSFS" == [yY] ]] && ZIP_NAME="${ZIP_NAME}-susfs"
[[ "$APPLY_LZ4" == [yY] ]] && ZIP_NAME="${ZIP_NAME}-lz4zstd"
[[ "$APPLY_SSG" == [yY] ]] && ZIP_NAME="${ZIP_NAME}-ssg"
ZIP_NAME="${ZIP_NAME}-$(date +%Y%m%d).zip"
zip -rq "../$ZIP_NAME" ./*
echo ">>> 打包完成: $(realpath ../$ZIP_NAME)"

#!/usr/bin/env bash
set -euo pipefail

IMMORTALWRT_VERSION="${1:-25.12.0}"
TARGET_PATH="${2:-x86/64}"
ARCH_PACKAGES="${3:-x86_64}"

case "$IMMORTALWRT_VERSION" in
  25.12.*) ;;
  *) echo "Only ImmortalWrt 25.12+ is supported, got: $IMMORTALWRT_VERSION" ; exit 1 ;;
esac

BASE="https://downloads.immortalwrt.org/releases/${IMMORTALWRT_VERSION}/targets/${TARGET_PATH}"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}/work"
OUTDIR="${GITHUB_WORKSPACE:-$(pwd)}/out"
rm -rf "$WORKDIR" "$OUTDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
cd "$WORKDIR"

echo "Downloading SDK index from $BASE/"
SDK_NAME="$(python3 - <<PY
import re, urllib.request
base='$BASE/'
html=urllib.request.urlopen(base, timeout=30).read().decode()
items=re.findall(r'href="([^"]*sdk-[^"]*Linux-x86_64\.tar\.zst)"', html, re.I)
if not items:
    raise SystemExit('SDK tarball not found at '+base)
print(items[0])
PY
)"

echo "SDK: $SDK_NAME"
curl -fsSLO "$BASE/$SDK_NAME"
tar --zstd -xf "$SDK_NAME" --strip-components=1

./scripts/feeds update -a
./scripts/feeds install -a

# Use the exact release build config; SDK defaults do not necessarily select
# optional kmods, so relying on defconfig alone can build no kmods.
curl -fsSL "$BASE/config.buildinfo" -o .config
make defconfig

# 强选 ESP AEAD/IPsec 必需的 kmod-crypto-* 包：ImmortalWrt 默认 .config 不全选。
# 这些包对应内核模块 seqiv.ko/echainiv.ko/gcm.ko/ghash.ko/sha256_generic.ko 等，
# 缺它们将导致 libreswan/pluto 在 XFRM_MSG_NEWSA 时报
# "Kernel was unable to initialize cryptographic operations" / "No such file or directory"。
# 依赖关系由 OpenWrt KernelPackage DEPENDS 自动解析，间接依赖包 make defconfig
# 会一并点亮，但显式列在这里可以保证关键模块一定被编译（防止某些 DEPENDS 是 HIDDEN 包）。
for pkg in \
  kmod-crypto-seqiv \
  kmod-crypto-echainiv \
  kmod-crypto-geniv \
  kmod-crypto-gcm \
  kmod-crypto-ghash \
  kmod-crypto-sha256 \
  kmod-crypto-sha512 \
  kmod-crypto-authenc \
  kmod-crypto-aead \
  kmod-crypto-ctr \
  kmod-crypto-gf128 \
  kmod-crypto-null \
  kmod-crypto-rng \
  kmod-crypto-hash \
  kmod-crypto-manager
do
  echo "CONFIG_PACKAGE_${pkg}=y" >> .config
done
make defconfig

# Build all selected kernel-package APKs (IPsec/XFRM + crypto) needed by
# Docker IKEv2/IPsec on host kernel. make defconfig 后所有 =y 都会进入编译列表。
make package/kernel/linux/compile -j"$(nproc)" V=s

mkdir -p bin/targets bin/packages
# 拷贝 IPsec/XFRM kmod（IKEv2 容器需要）+ crypto kmod（ESP AEAD 算法依赖）。
find bin/targets bin/packages -type f \( \
  -name 'kmod-ipsec-*.apk' -o \
  -name 'kmod-ipsec4-*.apk' -o \
  -name 'kmod-ipsec6-*.apk' -o \
  -name 'kmod-ipt-ipsec-*.apk' -o \
  -name 'kmod-xfrm-interface-*.apk' -o \
  -name 'kmod-nft-xfrm-*.apk' -o \
  -name 'kmod-crypto-seqiv-*.apk' -o \
  -name 'kmod-crypto-echainiv-*.apk' -o \
  -name 'kmod-crypto-geniv-*.apk' -o \
  -name 'kmod-crypto-gcm-*.apk' -o \
  -name 'kmod-crypto-ghash-*.apk' -o \
  -name 'kmod-crypto-sha256-*.apk' -o \
  -name 'kmod-crypto-sha512-*.apk' -o \
  -name 'kmod-crypto-authenc-*.apk' -o \
  -name 'kmod-crypto-aead-*.apk' -o \
  -name 'kmod-crypto-ctr-*.apk' -o \
  -name 'kmod-crypto-gf128-*.apk' -o \
  -name 'kmod-crypto-null-*.apk' -o \
  -name 'kmod-crypto-rng-*.apk' -o \
  -name 'kmod-crypto-hash-*.apk' -o \
  -name 'kmod-crypto-manager-*.apk' \
\) -exec cp -v {} "$OUTDIR"/ \;

cd "$OUTDIR"
for required in kmod-ipsec kmod-ipsec4 kmod-ipsec6 kmod-ipt-ipsec \
    kmod-crypto-seqiv kmod-crypto-echainiv kmod-crypto-geniv \
    kmod-crypto-gcm kmod-crypto-ghash kmod-crypto-sha256 \
    kmod-crypto-sha512 kmod-crypto-authenc kmod-crypto-aead \
    kmod-crypto-ctr kmod-crypto-gf128 kmod-crypto-null \
    kmod-crypto-rng kmod-crypto-hash kmod-crypto-manager; do
  ls "${required}"-*.apk >/dev/null 2>&1 || { echo "Missing required APK: $required" ; exit 1 ; }
done
ls -1 *.apk | sort > assets.txt
sha256sum *.apk assets.txt > SHA256SUMS
REVISION="$(curl -fsSL "$BASE/version.buildinfo" | head -n1)"
cat > buildinfo.txt <<EOF
IMMORTALWRT_VERSION=${IMMORTALWRT_VERSION}
TARGET=${TARGET_PATH}
ARCH_PACKAGES=${ARCH_PACKAGES}
REVISION=${REVISION}
SDK=${SDK_NAME}
EOF
cat buildinfo.txt
ls -lah

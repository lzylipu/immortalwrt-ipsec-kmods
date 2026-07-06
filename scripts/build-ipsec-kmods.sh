#!/usr/bin/env bash
set -euo pipefail

IMMORTALWRT_VERSION="${1:-25.12.0}"
TARGET_PATH="${2:-x86/64}"
ARCH_PACKAGES="${3:-x86_64}"

case "$IMMORTALWRT_VERSION" in
  25.12.*) ;;
  *) echo "Only ImmortalWrt 25.12+ is supported, got: $IMMORTALWRT_VERSION"; exit 1 ;;
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

# Build only kernel-package APKs needed by Docker IKEv2/IPsec on host kernel.
make defconfig
make package/kernel/linux/compile -j"$(nproc)" V=s

find bin/targets "$PWD/bin/packages" -type f \( \
  -name 'kmod-ipsec_*.apk' -o \
  -name 'kmod-ipsec4_*.apk' -o \
  -name 'kmod-ipsec6_*.apk' -o \
  -name 'kmod-ipt-ipsec_*.apk' -o \
  -name 'kmod-xfrm-interface_*.apk' -o \
  -name 'kmod-nft-xfrm_*.apk' \
\) -exec cp -v {} "$OUTDIR"/ \;

cd "$OUTDIR"
for required in kmod-ipsec kmod-ipsec4 kmod-ipsec6 kmod-ipt-ipsec; do
  ls "${required}"_*.apk >/dev/null 2>&1 || { echo "Missing required APK: $required"; exit 1; }
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

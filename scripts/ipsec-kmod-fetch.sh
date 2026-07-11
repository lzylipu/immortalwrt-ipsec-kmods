#!/usr/bin/env bash
set -euo pipefail

if [ "${ENABLE_IPSEC_KMODS:-yes}" = "no" ]; then
  echo "⚪️ 未启用 IPsec/XFRM kmod 集成"
  exit 0
fi

: "${IPSEC_KMOD_REPO:=lzylipu/immortalwrt-ipsec-kmods}"
: "${IMMORTALWRT_VERSION:?IMMORTALWRT_VERSION is required}"
: "${ARCH_PACKAGES:=x86_64}"
TARGET_PATH="x86/64"

case "$IMMORTALWRT_VERSION" in
  25.12.*) ;;
  *) echo "❌ IPsec kmod integration only supports ImmortalWrt 25.12.x, got: ${IMMORTALWRT_VERSION}" ; exit 1 ;;
esac

resolve_release() {
  if [ -n "${IPSEC_KMOD_RELEASE:-}" ] && [ "${IPSEC_KMOD_RELEASE}" != "auto" ]; then
    printf '%s\n' "$IPSEC_KMOD_RELEASE"
    return 0
  fi
  echo "🔎 Auto resolving IPsec kmod release for ${IMMORTALWRT_VERSION}" >&2
  python3 - <<'PY'
import json, re, urllib.request
import os
repo=os.environ['IPSEC_KMOD_REPO']
version=os.environ['IMMORTALWRT_VERSION']
url=f'https://api.github.com/repos/{repo}/releases?per_page=100'
releases=json.load(urllib.request.urlopen(url, timeout=30))
pat=re.compile(rf'^immortalwrt-{re.escape(version)}-x86-64-r\d+$')
for rel in releases:
    tag=rel.get('tag_name','')
    if pat.match(tag):
        print(tag)
        raise SystemExit(0)
raise SystemExit(f'No matching IPsec kmod release for {version} in {repo}')
PY
}

IPSEC_KMOD_RELEASE="$(resolve_release)"
BASE_URL="https://github.com/${IPSEC_KMOD_REPO}/releases/download/${IPSEC_KMOD_RELEASE}"
DEST="/home/build/immortalwrt/packages"
mkdir -p "$DEST"

echo "🔐 Downloading IPsec/XFRM + crypto kmod APKs from ${IPSEC_KMOD_REPO}@${IPSEC_KMOD_RELEASE}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

curl -fsSLO "${BASE_URL}/buildinfo.txt"
curl -fsSLO "${BASE_URL}/SHA256SUMS"
curl -fsSLO "${BASE_URL}/assets.txt"

grep -qx "IMMORTALWRT_VERSION=${IMMORTALWRT_VERSION}" buildinfo.txt || { echo "❌ version mismatch" ; cat buildinfo.txt ; exit 1 ; }
grep -qx "TARGET=${TARGET_PATH}" buildinfo.txt || { echo "❌ target mismatch" ; cat buildinfo.txt ; exit 1 ; }
grep -qx "ARCH_PACKAGES=${ARCH_PACKAGES}" buildinfo.txt || { echo "❌ arch mismatch" ; cat buildinfo.txt ; exit 1 ; }

required='kmod-ipsec kmod-ipsec4 kmod-ipsec6 kmod-ipt-ipsec \
  kmod-crypto-seqiv kmod-crypto-echainiv kmod-crypto-geniv \
  kmod-crypto-gcm kmod-crypto-ghash kmod-crypto-sha256 \
  kmod-crypto-sha512 kmod-crypto-authenc kmod-crypto-aead \
  kmod-crypto-ctr kmod-crypto-gf128 kmod-crypto-null \
  kmod-crypto-rng kmod-crypto-hash kmod-crypto-manager'
for pkg in $required; do
  grep -q "^${pkg}-.*\.apk$" assets.txt || {
    echo "❌ missing required kmod asset: ${pkg}"
    cat assets.txt
    exit 1
  }
done

while IFS= read -r asset; do
  [ -z "$asset" ] && continue
  case "$asset" in
    *.apk) curl -fsSLO "${BASE_URL}/${asset}" ;;
  esac
done < assets.txt

sha256sum -c SHA256SUMS
cp -v ./*.apk "$DEST"/

sed -E 's/-[0-9].*\.apk$//' assets.txt | tr '\n' ' ' > /tmp/ipsec-kmod-packages.env

echo "✅ IPsec/XFRM + crypto kmod APKs ready: $(cat /tmp/ipsec-kmod-packages.env)"

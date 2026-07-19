# 📦 immortalwrt-ipsec-kmods / ImmortalWrt IPsec Kernel Modules Builder

> 🌐 English | [简体中文](./README.md)
> Build `.apk` kernel modules required by IKEv2 IPsec/XFRM and Crypto acceleration for ImmortalWrt x86/64.
> 为 ImmortalWrt 25.12 x86/64 单独构建 Docker IKEv2 所需的 IPsec/XFRM + crypto 内核模块 `.apk`，供 `lzylipu/ImmortalWrt-ImageBuilder` 的 `lzy/ipsec-kmods` 分支按 Release tag 下载集成。

---

## 📖 English Summary

This repository builds and publishes kernel-module `.apk` packages for ImmortalWrt 25.12 x86/64 that are specifically required by Docker-hosted Libreswan/IKEv2 VPN servers (`hwdsl2/ipsec-vpn-server`). Without these kmods, the host kernel lacks `aes_gcm`, `seqiv`, `xfr_user` etc., causing IKEv2 Phase 2 `CHILD_SA` negotiations to fail with "Kernel was unable to initialize cryptographic operations" even when authentication succeeds.

---

## 🔍 为什么独立仓库 / Why a Separate Repository

OpenWrt/ImmortalWrt 的 kmod 不是普通用户态包，必须匹配：

- ImmortalWrt release
- target/subtarget
- arch packages
- kernel ABI / vermagic

所以这里单独编译并发布 Release assets，ImageBuilder 仓库只引用固定 tag，不用 `latest`，也不污染悟空 upstream 目录。

---

## 🔐 为什么还要 crypto kmod / Why Crypto KMODs Are Necessary

ImmortalWrt 25.12 默认 .config 不会全选 ESP AEAD 需要的 `kmod-crypto-*` 包（seqiv / echainiv / gcm / ghash / sha256 等），导致 Libreswan/pluto 在 `XFRM_MSG_NEWSA` 时报：

```
netlink response for Add SA esp.XXX@172.17.0.2: No such file or directory (errno 2)
netlink ext_ack: Kernel was unable to initialize cryptographic operations
```

IKEv2 协商完成（IKE SA 已 authenticated），但 CHILD_SA 始终建立不起来，手机端表现为"鉴权失败 / 一直转圈"。

把这些 crypto kmod 也打包到固件后，`hwdsl2/ipsec-vpn-server` 容器才能直接用宿主内核的 `aes_gcm` 等 AEAD 算法建立 IPsec SA。

---

## 🎯 默认目标 / Default Target

- ImmortalWrt: `25.12.0`
- Target: `x86/64`
- Arch packages: `x86_64`
- Release tag: `immortalwrt-25.12.0-x86-64-r37854`

---

## 📦 产物 / Artifacts

Release 会上传：

**IPsec/XFRM kmod（IKEv2 容器需要）：**
- `kmod-ipsec_*.apk`
- `kmod-ipsec4_*.apk`
- `kmod-ipsec6_*.apk`
- `kmod-ipt-ipsec_*.apk`
- `kmod-xfrm-interface_*.apk`
- `kmod-nft-xfrm_*.apk`

**crypto kmod（ESP AEAD 算法依赖）：**
- `kmod-crypto-seqiv_*.apk`
- `kmod-crypto-echainiv_*.apk`
- `kmod-crypto-geniv_*.apk`
- `kmod-crypto-gcm_*.apk`
- `kmod-crypto-ghash_*.apk`
- `kmod-crypto-sha256_*.apk`
- `kmod-crypto-sha512_*.apk`
- `kmod-crypto-authenc_*.apk`
- `kmod-crypto-aead_*.apk`
- `kmod-crypto-ctr_*.apk`
- `kmod-crypto-gf128_*.apk`
- `kmod-crypto-null_*.apk`
- `kmod-crypto-rng_*.apk`
- `kmod-crypto-hash_*.apk`
- `kmod-crypto-manager_*.apk`

**元数据 / Metadata：**
- `buildinfo.txt`
- `assets.txt`
- `SHA256SUMS`

---

## 🚀 自动发布逻辑 / Auto-Publish Logic

- 手动运行 workflow = auto-select latest `25.12.x`
- 每周二自动检查新 release
- Release tag format: `immortalwrt-{version}-x86-64-{revision-short}`
- 已有 tag 则跳过，避免重复编译

---

## 📄 许可证 / License

MIT License — see [LICENSE](./LICENSE)

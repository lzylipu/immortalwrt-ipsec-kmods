# immortalwrt-ipsec-kmods

为 ImmortalWrt 25.12 x86/64 单独构建 Docker IKEv2 所需的 IPsec/XFRM + crypto 内核模块 `.apk`，供 `lzylipu/ImmortalWrt-ImageBuilder` 的 `lzy/ipsec-kmods` 分支按 Release tag 下载集成。

## 为什么独立仓库

OpenWrt/ImmortalWrt 的 kmod 不是普通用户态包，必须匹配：

- ImmortalWrt release
- target/subtarget
- arch packages
- kernel ABI / vermagic

所以这里单独编译并发布 Release assets，ImageBuilder 仓库只引用固定 tag，不用 `latest`，也不污染悟空 upstream 目录。

## 为什么还要 crypto kmod

ImmortalWrt 25.12 默认 .config 不会全选 ESP AEAD 需要的 `kmod-crypto-*` 包（seqiv / echainiv / gcm / ghash / sha256 等），导致 Libreswan/pluto 在 `XFRM_MSG_NEWSA` 时报：

```
netlink response for Add SA esp.XXX@172.17.0.2: No such file or directory (errno 2)
netlink ext_ack: Kernel was unable to initialize cryptographic operations
```

IKEv2 协商完成（IKE SA 已 authenticated），但 CHILD_SA 始终建立不起来，手机端表现为"鉴权失败 / 一直转圈"。

把这些 crypto kmod 也打包到固件后，`hwdsl2/ipsec-vpn-server` 容器才能直接用宿主内核的 `aes_gcm` 等 AEAD 算法建立 IPsec SA。

## 默认目标

- ImmortalWrt: `25.12.0`
- Target: `x86/64`
- Arch packages: `x86_64`
- Release tag: `immortalwrt-25.12.0-x86-64-r37854`

## 产物

Release 会上传：

**IPsec/XFRM kmod（IKEv2 容器需要）：**
- `kmod-ipsec_*.apk`（含 af_key / xfrm_algo / xfrm_user）
- `kmod-ipsec4_*.apk`（含 esp4 / ah4）
- `kmod-ipsec6_*.apk`
- `kmod-ipt-ipsec_*.apk`
- `kmod-xfrm-interface_*.apk`
- `kmod-nft-xfrm_*.apk`

**crypto kmod（ESP AEAD 算法依赖，给宿主内核提供 seqiv/gcm/sha256 等模块）：**
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

**元数据：**
- `buildinfo.txt`
- `assets.txt`
- `SHA256SUMS`

`assets.txt` 给 ImageBuilder 下载脚本使用；`buildinfo.txt` 用来做版本/target/arch 匹配检查。

## 自动发布逻辑

- 手动运行 workflow 时，`immortalwrt_version` 留空会自动选择 ImmortalWrt downloads 中最新的 `25.12.x`。
- 每周二会自动检查一次新 `25.12.x` release。
- Release tag 自动格式：`immortalwrt-<version>-x86-64-<revision-short>`，例如 `immortalwrt-25.12.0-x86-64-r37854`。
- 如果对应 tag 已存在，workflow 会直接跳过，避免重复编译。
- 产物包括 `assets.txt`、`SHA256SUMS`、`buildinfo.txt` 和 IPsec/XFRM + crypto kmod `.apk`。

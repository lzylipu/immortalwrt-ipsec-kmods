# immortalwrt-ipsec-kmods

为 ImmortalWrt 25.12 x86/64 单独构建 Docker IKEv2 所需的 IPsec/XFRM 内核模块 `.apk`，供 `lzylipu/ImmortalWrt-ImageBuilder` 的 `lzy/ipsec-kmods` 分支按 Release tag 下载集成。

## 为什么独立仓库

OpenWrt/ImmortalWrt 的 kmod 不是普通用户态包，必须匹配：

- ImmortalWrt release
- target/subtarget
- arch packages
- kernel ABI / vermagic

所以这里单独编译并发布 Release assets，ImageBuilder 仓库只引用固定 tag，不用 `latest`，也不污染悟空 upstream 目录。

## 默认目标

- ImmortalWrt: `25.12.0`
- Target: `x86/64`
- Arch packages: `x86_64`
- Release tag: `immortalwrt-25.12.0-x86-64-r37854`

## 产物

Release 会上传：

- `kmod-ipsec_*.apk`
- `kmod-ipsec4_*.apk`
- `kmod-ipsec6_*.apk`
- `kmod-ipt-ipsec_*.apk`
- `kmod-xfrm-interface_*.apk`
- `kmod-nft-xfrm_*.apk`
- `buildinfo.txt`
- `assets.txt`
- `SHA256SUMS`

`assets.txt` 给 ImageBuilder 下载脚本使用；`buildinfo.txt` 用来做版本/target/arch 匹配检查。

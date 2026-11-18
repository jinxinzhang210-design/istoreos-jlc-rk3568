# iStoreOS for JLC RK3568 8125 — GitHub Actions 云编译套件

这块板子没有官方 iStoreOS 固件。此仓库把从 `jlc_rk3568_8125.img` 提取的板级适配资料，
注入官方 iStoreOS 24.10 源码，在 GitHub 的境外 runner 上编译出真正可刷的固件。

**为什么用云编译**：本机 `raw.githubusercontent.com` / `git.openwrt.org` 不通，
但编译全程跑在 GitHub 的 runner 上，源码、feeds、源码包都在境外拉取，与本机网络无关。
本机只需能把这个小仓库 `git push` 到 GitHub 一次。

---

## 目录结构

```
.github/workflows/build-istoreos-jlc.yml   编译流程（唯一入口）
board/rk3568-jlc-custom.dts                反编译的板级设备树（自包含，可被 dtc 编译）
board/rk3568-jlc-custom.dtb                原始 DTB（备份/救急）
board/device-profile.mk                    iStoreOS armv8.mk 设备定义
config.seed                                .config 种子（可自由加包）
scripts/inject.sh                           注入 DTS / 设备定义 / config
scripts/patch_uboot.py                      把新设备加入 U-Boot BUILD_DEVICES（关键）
```

## 三步开始

### 1. 建一个空的 GitHub 仓库
登录 GitHub → 右上角 `+` → **New repository**：
- 名字随意，如 `istoreos-jlc-build`
- **Public**（私有仓库 Actions 有分钟数限制，Public 免费额度充足）
- **不要**勾选 "Add a README file" / "Add .gitignore"（保持完全空仓库）

### 2. 把本目录推上去
在本目录打开 PowerShell，执行（把 URL 换成你自己的仓库）：

```powershell
powershell -ExecutionPolicy Bypass -File .\push-to-github.ps1 -RepoUrl "https://github.com/<你的用户名>/istoreos-jlc-build.git"
```

脚本会 `git init` → 提交 → `push`。首次推送若弹出 GitHub 登录，用浏览器授权即可；
若用 Personal Access Token，把它填进 URL：`https://<user>:<PAT>@github.com/...`。

### 3. 触发编译
推送成功后，push 事件会**自动**开始编译；也可手动触发：
仓库页 → **Actions** → 左侧 `Build iStoreOS - JLC RK3568 8125` → **Run workflow**。

可填参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `branch` | `istoreos-24.10` | iStoreOS 源码分支 |
| `jobs` | `2` | `make -jN`；免费 runner 2 vCPU / 7 GB，`2` 最稳，`4` 更快但吃内存 |
| `runner` | `ubuntu-22.04` | 若 22.04 被弃用改 `ubuntu-24.04` |
| `make_release` | `false` | 设 `true` 同时发布到 Releases |
| `extra_packages` | 空 | 额外包名，空格分隔，如 `luci-app-upnp htop` |

首次全编译约 **1–3 小时**。完成后在 Actions 运行页底部下载
`istoreos-jlc-firmware`，里面是：

```
istoreos-rockchip-armv8-jlc_rk3568_8125-squashfs-sysupgrade.img.gz
```

`istoreos-jlc-diagnostics` 里有 `build.log`、`.config` 和编出来的 DTB，编译失败时发我这个日志即可排错。

---

## 这个 workflow 做了哪些本地版没有的事

1. **扩盘**：`easimon/maximize-build-space` 把 runner 的 14GB 合并成 ~90GB（OpenWrt 需要 40GB+）。
2. **U-Boot 关联**：`include/u-boot.mk` 只在设备的 `BUILD_DEVICES` 命中时才把 u-boot 包设为 `DEFAULT:=y`。
   新设备不在 `nanopi-r5s-rk3568` 的列表里，若不修补，`pine64-img` 的 `dd` 会因找不到
   `nanopi-r5s-rk3568-u-boot-rockchip.bin` 而失败。`patch_uboot.py` + `config.seed` 双保险解决。
3. **硬校验**：`make defconfig` 后强制确认设备符号与 u-boot 包都被选中，否则立即报错，
   不会浪费两小时才发现配置被 defconfig 丢掉。
4. **失败可诊断**：`if: always()` 上传 build.log / .config / dtb，即使编译失败也能拿到日志。

## 已核实的源码事实（istoreos-24.10）

- 内核 `6.6`；`target/linux/rockchip/dts/` 按 SoC 分子目录（`rk3568/` 存在），
  所以 `DEVICE_DTS := rk3568/rk3568-jlc-custom` + `DEVICE_DTS_DIR := ../dts` 路径正确。
- `Device/Default` 的 `KERNEL = kernel-bin | lzma | fit lzma $$(DTS_DIR)/$$(DEVICE_DTS).dtb`；
  自定义 DTS 设备（nanopi-r2s/r4s）正是用 `$$(KDIR)/image-*.dtb` 这套写法。
- feeds 全在 GitHub：`jjm2473/packages`、`jjm2473/luci`、`openwrt/routing`、
  `openwrt/telephony`、`linkease/istore`(store)、`jjm2473/openwrt-third`。
  iStore 商店包名确认为 `luci-app-store`。
- `u-boot-nanopi-r5s-rk3568` 确实存在（U-Boot 2024.10）。

## ⚠️ 风险与刷机

- **DTB 来自 6.12 内核的供体镜像，而 iStoreOS 24.10 是 6.6**：DTS 语法能编过，
  但个别 Rockchip BSP 绑定（电源域 / PCIe reset GPIO）可能与 6.6 驱动不完全一致。
  这是最可能出问题的地方，日志会告诉我们。
- **首次启动务必接 TTL 串口**（`1500000 8N1`），备好 MaskROM / RKDevTool 救砖。
- 刷的是 `squashfs-sysupgrade.img.gz`：先解压成 `.img`，用 balenaEtcher / `dd` /
  RKDevTool 写入 SD 或 eMMC。
- 别直接刷官方 NanoPi R5S / R66S 固件：网口顺序和 LED 大概率不对。

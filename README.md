# MT6989 Ace5竞速版 6.1.157 OKI内核构建

一加 Ace 5 竞速版（天玑 9400e / MT6989）定制内核，基于 [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650) 的构建体系，内核版本与 Ace5 竞速版 2026-08 官方固件 `boot_a` **精确匹配**。

## 版本匹配（关键）

| 项 | 值 |
|---|---|
| 设备 | 一加 Ace 5 竞速版 (MT6989) |
| 内核 | 6.1.157（与 boot_a 横幅 `6.1.157-android14-11-o-gc2dad16af736` 一致） |
| 源码 | [OnePlusOSS/android_kernel_oneplus_mt6989](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989) @ `822beed4`（SHA固定） |
| SSG移植源 | cctv18 fork @ `16bc5565`（6.1.134，SSG 调度器仅存于此树） |
| 编译器 | LLVM-Clang 20 r547379（与 cctv18 构建体系一致） |

OKI 模式保留官方全套驱动/调度/充电，vendor 模块留在设备分区不动，无需相同版本 GKI 刷入限制；版本后缀默认与原版一致，模块 vermagic 匹配。

## 集成内容

- **KernelSU-Next**（dev-susfs 分支，内置 GKI 模式，非 LKM）
- **SUSFS** 全套（cctv18/susfs4oki oki-android14-6.1 + 69_hide_stuff）
- **性能**：O2 编译优化、lz4 1.10.0 + zstd 1.5.7、三星 SSG IO 调度器（自 134 树移植）、CVE-2026-43499 修复
- **网络**：ipset/iptables 全家桶（AdGuard Home、透明代理等可用）、可选 BBR/Brutal
- **安全**：Baseband-guard 内核级防格机
- 完整保留 OPLUS 官方调度/游戏加速设施（sched_assist、cpu_boost、f2fs appboost/dedup 等 OKI 树内功能）

> 关于"风驰游戏内核"：其源码未公开，无法直接集成。本构建保留官方全部游戏调度设施，并叠加上述开源性能补丁，达到同方向的优化目标。任何内核都无法承诺"一点不卡"，实际体验受温控、调度策略、用户态影响。

## 使用（GitHub Actions）

1. 在你的 GitHub 账户创建空仓库（如 `ace5r-kernel-157`），推送本目录：
   ```bash
   git init -b main
   git add .
   git commit -m "MT6989 6.1.157 OKI kernel: KSU-Next + SUSFS"
   git remote add origin git@github.com:<你的用户名>/ace5r-kernel-157.git
   git push -u origin main
   ```
2. 仓库 Actions 页启用 workflow
3. 运行 `6.1.157 MT6989 Ace5竞速版 OKI内核快速构建`，全部选项保持默认即可（默认即 KernelSU-Next + SUSFS 全开）
4. 构建完成从 Artifacts 下载 AnyKernel3 zip（首次约 20-40 分钟，ccache 命中后约 6-10 分钟）

## 本地构建（x86_64 Linux）

```bash
KSU_TYPE=ksunext bash local/build-6.1.157-mt6989.sh
```

## 刷入与回退

- 刷入：KernelSU Next 管理器刷 AK3 zip，或 TWRO/KernelSU 兼容 recovery
- 回退：fastboot 刷回原版 `boot_a` 备份即可（刷前请自备）
- **务必先备份数据与原版 boot 分区**；变砖责任自负

## 致谢

- [cctv18](https://github.com/cctv18) — 构建体系、ccache-ECS、SSG/BBG/SUSFS 移植
- [pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next)、[tiann/KernelSU](https://github.com/tiann/KernelSU)
- [OnePlusOSS](https://github.com/OnePlusOSS) 官方内核源码

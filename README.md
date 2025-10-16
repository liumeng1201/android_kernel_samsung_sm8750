
# Kokuban 内核 for 三星 Galaxy S25 系列

<p align="center">
<img src="https://raw.githubusercontent.com/YuzakiKokuban/Kokuban_Kernel_CI_Center/main/docs/kokuban_logo.png" alt="Logo" width="150">
</p>

<p align="center">
<a href="https://github.com/liumeng1201/android_kernel_samsung_sm8750/releases"><img src="https://img.shields.io/github/v/release/YuzakiKokuban/android_kernel_samsung_sm8750?style=for-the-badge&logo=github&color=blue" alt="GitHub release"></a>
<a href="https://t.me/YuzakiKokuban"><img src="https://img.shields.io/badge/Telegram-交流群-blue.svg?style=for-the-badge&logo=telegram" alt="Telegram"></a>
</p>

这是一个基于三星官方内核源码构建的，适用于 **三星 Galaxy S25 系列** 的高性能自定义内核。它旨在提供卓越的稳定性和流畅度，同时集成了最新的 KernelSU 功能，为您带来最佳的玩机体验。

## 📌 主要特性

* **官方源码基础**: 基于三星官方最新的内核源码，确保最佳的兼容性和稳定性。

* **性能优化**: 针对性的性能调度优化，带来更流畅的日常使用和游戏体验。

* **KernelSU 集成**: 内置多种 KernelSU 版本（包括官方版、MKSU、SukiSU-Ultra），开箱即用。

* **版本信息**: `-android15-ci-BYI3`

## 🧩 可用版本详解

* **LKM (Loadable Kernel Module)**

  * 未内置任何 Root 方案，保持官方内核的纯净性。

  * **安全性**: 仅移除了部分影响玩机的三星安全策略，如 RKP, KDP 等。

  * **使用方式**: 需要您通过 KernelSU Manager App 手动修补设备的 `init_boot` 分区来实现 Root。

* **KSU (KernelSU)**

  * 内置官方原版 KernelSU，提供最原汁原味的 Root 体验。

* **MKSU (Magic KernelSU)**

  * 内置由 `5ec1cff` 修改的 KernelSU，特性是支持 Magic Mount，可以更方便地挂载模块。

* **SukiSUU (SukiSU-Ultra)**

  * 内置功能强大的 SukiSU-Ultra，支持 SUSFS 和 KPM 模块，为高级玩家提供更多可玩性。

## ⚙️ 安装指南

1. **解锁 Bootloader**: 请确保您的设备已经解锁 Bootloader。

2. **刷入 Recovery**: 推荐使用最新的 TWRP 或 OrangeFox Recovery。

3. **刷入内核**: 在 Recovery 中刷入本项目 Releases 页面下载的内核 `zip` 包。

4. **（仅 LKM 版本需要）修补 `init_boot`**:

   * 备份您设备当前的 `init_boot.img`。

   * 使用 KernelSU Manager App 选择并修补该镜像。

   * 将修补后生成的 `init_boot.img` 通过 Fastboot 或 Recovery 刷入设备的 `init_boot` 分区。

5. **重启设备**, 享受新内核带来的快感！

## 📥 下载

所有最新版本都可以在 [**Releases 页面**](https://github.com/liumeng1201/android_kernel_samsung_sm8750/releases) 找到。

## ⚠️ 免责声明

刷机有风险，操作需谨慎。在进行任何操作前，请务必完整备份您的个人数据。因刷入此内核而导致的任何设备损坏或数据丢失，本人概不负责。

---

# 🥺 小小拜托

## 求求你了，不要拿这个内核去适配 KernelSU-Next 啦～
😭😭😭

KernelSU-Next 不是 KernelSU 官方开发的，也不是官方认可的改进版，
而且它的开发者有一些很让人摸不着头脑的操作……

[岁月史书](https://web.archive.org/web/20250211155215/https://github.com/rifsxd/KernelSU-Next/issues/145)

如果你想要类似功能的话，拜托用 **SukiSU** 好不好嘛～
它更稳定，也更值得信赖！

---

## 如果你还是坚持要适配 KernelSU-Next……
我真的会呜呜呜哭出来的！！！
(｡•́︿•̀｡)
拜托啦～谢谢谢谢！

---



<p align="center">
<a href="https://www.paypal.me/LangQin280">☕ Support Me</a>
</p>

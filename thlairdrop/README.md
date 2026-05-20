# THLAirDrop (LocalSend HarmonyOS 原生客户端)

<p align="center">
  <img src="https://localsend.org/img/logo-512.png" alt="LocalSend Logo" width="120" height="120" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);"/>
</p>

## 🌟 项目简介

**THLAirDrop** 是基于 **HarmonyOS NEXT** 平台开发的原生 LocalSend 客户端。项目采用 **ArkTS**、**Stage 模型** 以及 **C++ NAPI** 混合开发，实现与 Windows、macOS、Linux、Android、iOS 等全平台 LocalSend 客户端的无缝互通，提供局域网内免流量、HTTPS 动态加密的高速文件与消息传输体验。

---

## 📖 功能使用指南

为了帮助您快速上手 **THLAirDrop**，以下是主要功能的使用方法与页面说明：

### 1. 首次启动与初始化
当您首次打开应用时，会弹窗进行网络与存储权限的使用说明。请您点击**同意/确定**以开启网络扫描和文件读写权限，保障应用的正常直连投送。

<p align="center">
  <img src="./image/首次提醒.png" alt="首次提醒" width="280" style="border-radius: 12px; border: 1px solid #eaeaea; box-shadow: 0 4px 12px rgba(0,0,0,0.08);"/>
</p>

### 2. 接收文件与状态概览
在 **"接收" (Receive)** 选项卡页面：
- **状态切换**：通过顶部的绿色开关，可轻松开启或关闭本机的局域网文件接收服务。
- **设备名片**：能直观查看当前设备的别名（例如 `武汉铭研`）、通信端口（默认 `53317`）以及当前的局域网 IP 地址。
- **传输历史**：点击底部的 "查看历史接收数据" 按钮，可直接进入历史传输列表，管理和快速定位已接收的本地文件。

<p align="center">
  <img src="./image/接受页面.png" alt="接收页面" width="280" style="border-radius: 12px; border: 1px solid #eaeaea; box-shadow: 0 4px 12px rgba(0,0,0,0.08);"/>
</p>

### 3. 选择资源与发现发送
在 **"发送" (Send)** 选项卡页面：
- **选择类型**：支持投送 **文件**（本地文档）、**媒体**（图库照片或视频）以及 **文本**（直接输入文字投送，支持剪贴板一键粘贴并自动定位本地已选数据）。
- **设备发现**：选择好资源后，应用会自动扫描局域网，在下方展示所有已开启 LocalSend 服务的其他平台设备。点击对应设备卡片即可立即投送。
- **手动扫描**：如遇复杂局域网，可点击右上角图标，手动输入对方的 IP 地址进行强行扫描直连。

<p align="center">
  <img src="./image/发送页面.png" alt="发送页面" width="280" style="border-radius: 12px; border: 1px solid #eaeaea; box-shadow: 0 4px 12px rgba(0,0,0,0.08);"/>
</p>

### 4. 传输历史与管理
在 **"传输历史" (History)** 页面：
- 能够清晰按时间线排列查看以往所有成功、失败或取消的文件接收记录。
- 支持点击文件条目直接在系统中查看或调用系统关联应用打开，并支持点击一键清空所有历史列表。

<p align="center">
  <img src="./image/传输历史.png" alt="传输历史" width="280" style="border-radius: 12px; border: 1px solid #eaeaea; box-shadow: 0 4px 12px rgba(0,0,0,0.08);"/>
</p>

### 5. 个性化设置
在 **"设置" (Settings)** 选项卡页面：
- **设备信息修改**：可修改本机的别名（Alias）、监听端口（Port）。
- **PIN 码安全校验**：支持开启 PIN 安全校验。开启后，其他设备向您投送时必须输入配对 PIN 码，大幅提升公共网络下的投送安全性。
- **偏好设定**：自由选择“常规”（主题色、明暗主题）、“语言一键切换”以及查看“关于与隐私声明”等。

<p align="center">
  <img src="./image/设置页面.png" alt="设置页面" width="280" style="border-radius: 12px; border: 1px solid #eaeaea; box-shadow: 0 4px 12px rgba(0,0,0,0.08);"/>
</p>

---

## 🚀 核心特性

- **⚡ 原生高性能**: 基于 ArkUI 声明式开发框架，提供符合鸿蒙原生的丝滑交互与精致过渡动画，内存与 CPU 占用极低。
- **🔒 安全加密**: 局域网内采用 REST API 交互，基于 HTTPS/TLS 协议对数据流进行动态端到端加密，证书在线即时生成，确保数据隐私安全。
- **📡 智能发现**: 自动通过 UDP 广播与组播技术发现局域网内的其他 LocalSend 设备；特别针对模拟器与复杂路由网络支持 **Manual Scan (手动 IP 扫描)** 以强力直连。
- **📂 便捷管理**: 支持一键开启/关闭本地接收服务、支持一键修改存储路径、查看传输历史。
- **🎨 现代个性化**: 完整的主题自适应机制，支持 Light / Dark 明暗模式与多种主题配色；支持多国语言一键切换。

---

## 🛠️ 技术路线与核心架构

**THLAirDrop** 采用 HarmonyOS NEXT 推荐的 **ArkTS 声明式前端 + C++ NAPI 高性能后端** 的双层混合架构。既保留了原生 ArkUI 丝滑、自适应的交互表现力，又赋予了网络传输层接近裸机性能的并发和数据吞吐能力。

### 1. 整体架构设计

```text
 ┌────────────────────────────────────────────────────────┐
 │                      ArkUI 视图层                       │
 │      (Index.ets / SendTab.ets / SettingsTab.ets 等)      │
 └──────────────────────────┬─────────────────────────────┘
                            │ (通过 State/Link 驱动)
 ┌──────────────────────────▼─────────────────────────────┐
 │                    ETS 业务逻辑与工具                     │
 │          (ThemeManager / I18nManager / API服务)          │
 └──────────────────────────┬─────────────────────────────┘
                            │ (调用 Service 代理)
 ┌──────────────────────────▼─────────────────────────────┐
 │                     C++ NAPI 桥接层                     │
 │      (实现 JS 类型到 C++ 类型转换、生命周期托管与回调注册)       │
 └──────────────────────────┬─────────────────────────────┘
                            │ (高效 C++ 接口调用)
 ┌──────────────────────────▼─────────────────────────────┐
 │                  C++ 核心网络与传输引擎                   │
 │  ┌───────────────────────┬──────────────────────────┐  │
 │  │      HTTPS/TLS        │       UDP 组播监听       │  │
 │  │   (基于 OpenSSL 传输)  │    (广播与 Manual Scan)  │  │
 │  ├───────────────────────┴──────────────────────────┤  │
 │  │                 多线程高并发传输线程池                  │  │
 │  └──────────────────────────────────────────────────┘  │
 └────────────────────────────────────────────────────────┘
```

### 2. 核心技术选型与实现机制

#### A. UI 表现层 (ArkTS & Stage 模型)
* **响应式状态管理**：采用最新的 `@State`, `@Prop`, `@Link`, `@Provide` 装饰器构建单一数据源，确保多语言切换、暗黑模式切换等状态能毫秒级全页面同步。
* **Stage 模型协同**：全面适配 Stage 模型。利用 `UIAbility` 的生命周期，在应用切入后台时优雅挂起部分扫描任务，并在回到前台时自动唤醒，以实现极致的电量和网络消耗控制。

#### B. 高性能传输引擎 (C++ NAPI 核心)
* **为什么要用 C++ NAPI 混合架构？**
  鸿蒙的 ArkTS 运行在 ArkCompiler 上，尽管其执行效率极高，但面对局域网高并发、高带宽的文件流吞吐时，频繁的垃圾回收（GC）和线程同步会对 UI 产生微小抖动。采用 C++ NAPI，我们可以：
  1. **规避 UI 主线程阻塞**：将所有重度网络 I/O（如 TLS 握手、大数据包分片拼接）卸载到 C++ 独立工作线程池中，确保 ArkUI 始终以稳定的 120Hz 满帧运行。
  2. **零拷贝（Zero-Copy）大文件直写**：利用 C++ `mmap` (内存映射) 及底层沙箱文件描述符直写，数据从 Socket 缓冲区读取后直接写入系统存储，最大化降低内存占用和 CPU 拷贝开销。

#### C. LocalSend v2 协议与安全机制
* **局域网 TLS 端到端加密**：
  * 基于 LocalSend 协议，设备发现后，双方通过 REST API 交互。
  * **动态自签证书**：每次服务启动时，C++ 传输引擎会在本地动态生成临时的公私钥对（RSA/ECDSA），并基于此生成自签名 X.509 证书。
  * **端到端加密 (E2EE)**：即使在公共 Wi-Fi 环境下，所有通过 TCP 传送的文件流和文本流也都会经过 TLS 握手后的对称密钥加密，杜绝局域网抓包监听。
* **双模式设备发现**：
  * **UDP 多播/组播 (Multicast)**：在同一局域网下，通过 `224.0.0.1` (或协议指定的组播组) 及 `53317` 端口发送/监听心跳广播，实现即开即现。
  * **手动 IP 强直连 (Manual Scan)**：针对鸿蒙模拟器（处于 NAT 隔离网络）以及部分路由关闭了组播的环境，支持通过直接 TCP 连接指定 IP 的 `53317` 端口，绕过组播壁垒完成直接通信。

### 3. 性能调优指标

* **多线程并发模型**：C++ 传输层采用 `libuv` / 原生线程池。为每个大文件传输任务分配一个工作者线程，最大支持多文件并行断点续传。
* **物理路径直写**：避开 ETS 层的字符串转换，直接在 C++ 中使用系统底层的 `write(fd, buf, len)`，保证大文件写入时的绝对速度。
* **最低运行要求**：HarmonyOS NEXT Beta (API 11+) / 推荐使用 API 12 及其以上系统。

---

## 📦 目录结构说明

```text
thlairdrop/
├── AppScope/                # 全局应用配置与资源 (图标、App名称等)
├── entry/                   # 主 Module 模块
│   ├── src/main/cpp/        # C++ NAPI 底层核心代码 (提供高性能加密传输、端口监听和套接字服务)
│   ├── src/main/ets/        # ArkTS (ETS) 业务代码
│   │   ├── common/          # 公共组件与定义
│   │   ├── components/      # UI 选项卡组件 (SendTab, ReceiveTab, SettingsTab)
│   │   ├── entryability/    # Ability 生命周期管理
│   │   ├── models/          # 数据实体模型
│   │   ├── pages/           # 页面视图 (Index 主页、HelpPage 帮助页、ThirdPartyLicenses 第三方许可、TransferHistory 传输历史)
│   │   ├── service/         # NAPI 核心服务的桥接调用
│   │   └── utils/           # 工具类 (主题管理 ThemeManager、多语言管理 I18nManager)
│   ├── src/main/resources/  # 模块级资源 (字符串、多媒体、Syscap等)
│   └── oh-package.json5     # 模块级依赖配置文件
├── build-profile.json5      # 编译打包配置文件
└── oh-package.json5         # 工程级依赖配置文件
```

---

## 🏗️ 编译与开发准备

### 1. 开发工具安装
- 下载并安装最新的 **DevEco Studio** (建议支持 API 11/12+ 的版本)。
- 确保已下载并正确配置 **HarmonyOS NEXT SDK**。

### 2. 初始化依赖
在 `thlairdrop` 目录下，使用终端运行以下命令，下载项目所需的鸿蒙第三方库依赖：
```bash
ohpm install
```

### 3. 配置证书与签名
项目中已提供了用于测试的开发与发布证书（包含 `thl.p12`、`开发证书.cer`、`发布证书.cer`、`airdrop_disRelease.p7b` 等文件）。
1. 打开 **DevEco Studio** 并导入 `thlairdrop` 文件夹。
2. 依次选择菜单 `File` -> `Project Structure` -> `Signing Configs`。
3. 选择 `Automatically generate signature` (自动生成签名)；或者手动配置已有的 HarmonyOS 官方签名文件。

### 4. 运行和调试
- **真机/模拟器**: 连接您的鸿蒙设备，确保已开启开发者调试模式。
- 在 DevEco Studio 的运行配置中选择 `entry` 模块，点击 **Run** 运行/调试。

---

## ⚠️ 常见问题与网络排查 (Troubleshooting)

> [!IMPORTANT]
> 由于 HarmonyOS 的网络安全沙箱机制以及不同局域网环境的特殊性，当您在使用中发现无法搜索到设备或传输失败时，请进行以下排查：

### 1. 模拟器无法发现其他设备？
- **原因**: 鸿蒙模拟器通常运行在 NAT 网络隔离模式下，UDP 组播发现报文无法直接跨网段投递。
- **解决办法**: 
  - 请在 **"发送 (Send)"** 页面使用 **Manual Scan (手动扫描)** 功能，输入目标接收端设备的真实局域网 IP 地址进行直连发送。
  - 或者改用真机进行测试，并确保真机与接收端处于同一个 Wi-Fi 热点/局域网段下（不能开启 AP 隔离）。

### 2. 权限问题
- 确保应用已在系统设置中获得网络相关的必要权限（如局域网发现）。
- 权限已在 `entry/src/main/module.json5` 中声明，系统会自动在安装时进行授信：
  - `ohos.permission.INTERNET` (访问外部网络)
  - `ohos.permission.GET_WIFI_INFO` (获取WiFi网络状态，用于获取并展示本机IP)

### 3. 端口冲突
- 默认的服务监听端口为 `53317`。如果该端口被系统中的其他进程占用，可在本应用的 **"设置 (Settings)"** 页面修改监听端口。

---

## 🤝 参与贡献

我们非常欢迎任何形式的贡献，包括但不限于 Bug 修复、新功能建议、代码优化及翻译！
在提交 PR 之前，请阅读根目录的 [CONTRIBUTING.md](../CONTRIBUTING.md) 以了解详细规则。

---
*Created by [never88gone](https://github.com/never88gone) with ❤️ for the HarmonyOS Ecosystem.*

# THLAirDrop (LocalSend HarmonyOS 原生客户端)

<p align="center">
  <img src="https://localsend.org/img/logo-512.png" alt="LocalSend Logo" width="120" height="120" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);"/>
</p>

## 🌟 项目简介

**THLAirDrop** 是基于 **HarmonyOS NEXT** 平台开发的原生 LocalSend 客户端。项目采用 **ArkTS**、**Stage 模型** 以及 **C++ NAPI** 混合开发，实现与 Windows、macOS、Linux、Android、iOS 等全平台 LocalSend 客户端的无缝互通，提供局域网内免流量、HTTPS 动态加密的高速文件与消息传输体验。

---

## 🚀 核心特性

- **⚡ 原生高性能**: 基于 ArkUI 声明式开发框架，提供符合鸿蒙原生的丝滑交互与精致过渡动画，内存与 CPU 占用极低。
- **🔒 安全加密**: 局域网内采用 REST API 交互，基于 HTTPS/TLS 协议对数据流进行动态端到端加密，证书在线即时生成，确保数据隐私安全。
- **📡 智能发现**: 自动通过 UDP 广播与组播技术发现局域网内的其他 LocalSend 设备；特别针对模拟器与复杂路由网络支持 **Manual Scan (手动 IP 扫描)** 以强力直连。
- **📂 便捷管理**: 支持一键开启/关闭本地接收服务、支持一键修改存储路径、查看传输历史。
- **🎨 现代个性化**: 完整的主题自适应机制，支持 Light / Dark 明暗模式与多种主题配色；支持多国语言一键切换。

---

## 🛠 技术架构

- **前端 UI**: ArkTS (基于最新的 Stage 架构设计)
- **网络与传输核心**: C++ NAPI (集成原生的高性能 Socket、TCP/UDP 和 TLS 连接，保障大文件传输的高效性)
- **构建系统**: Hvigor + Ohpm
- **最低运行要求**: HarmonyOS NEXT Beta (API 11+) / 推荐使用 API 12 及其以上

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

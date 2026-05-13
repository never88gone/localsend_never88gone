# LocalSend HarmonyOS - Rust + C++ + NAPI 集成指南

## 架构概述

```
┌─────────────────────────────────────────────────────────────┐
│                     ArkTS (UI 层)                            │
│  import libEntry from 'libentry.so'                          │
│  libEntry.startServer(alias, port)                           │
│  libEntry.scanDevices()                                      │
└─────────────────────────┬───────────────────────────────────┘
                          │ NAPI
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   C++ (桥接层)                               │
│  localsend.cpp                                               │
│  - 参数转换 (ArkTS <-> C++)                                  │
│  - 调用 Rust FFI 函数                                        │
└─────────────────────────┬───────────────────────────────────┘
                          │ FFI (extern "C")
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Rust (核心层)                             │
│  rust/src/lib.rs                                             │
│  - UDP 多播设备发现                                          │
│  - HTTP 服务器                                               │
│  - 文件传输                                                  │
└─────────────────────────────────────────────────────────────┘
```

## 文件结构

```
entry/src/main/cpp/
├── CMakeLists.txt          # CMake 配置，链接 Rust 库
├── localsend.cpp           # NAPI 模块，桥接 ArkTS 和 Rust
├── include/
│   └── localsend_rust.h    # Rust FFI 头文件
├── rust/
│   ├── Cargo.toml          # Rust 项目配置
│   ├── build.rs            # 构建脚本（生成 C 头文件）
│   └── src/
│       └── lib.rs          # Rust 核心实现
├── build_rust.sh           # Rust 编译脚本
└── build_rust_simple.sh    # 简化编译脚本
```

## 环境准备

### 1. 安装 Rust

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustups.rs | sh

# 配置环境变量
source ~/.cargo/env

# 验证安装
rustc --version
cargo --version
```

### 2. 添加编译目标

```bash
# 标准目标（用于测试）
rustup target add aarch64-unknown-linux-gnu
rustup target add x86_64-unknown-linux-gnu

# HarmonyOS 目标（需要 OpenHarmony 工具链）
rustup target add aarch64-unknown-linux-ohos
rustup target add armv7-unknown-linux-ohos
```

## 编译步骤

### 方式一：简化编译（推荐用于开发测试）

```bash
cd entry/src/main/cpp
./build_rust_simple.sh
```

### 方式二：完整编译（用于 HarmonyOS 设备）

```bash
cd entry/src/main/cpp
./build_rust.sh release aarch64-unknown-linux-ohos
```

### 方式三：手动编译

```bash
cd entry/src/main/cpp/rust

# Debug 版本
cargo build

# Release 版本
cargo build --release

# 指定目标
cargo build --release --target aarch64-unknown-linux-gnu
```

## 在 DevEco Studio 中使用

1. **编译 Rust 库**
   ```bash
   cd entry/src/main/cpp
   ./build_rust_simple.sh
   ```

2. **更新 CMakeLists.txt 中的路径**（如果需要）
   
   确保 `RUST_LIB_DIR` 指向正确的 Rust 编译输出目录。

3. **重新构建项目**
   
   在 DevEco Studio 中点击 Build > Rebuild Project

4. **验证链接**
   
   检查构建日志，应该看到：
   ```
   Found Rust library: .../liblocalsend_harmony.a
   ```

## ArkTS API 使用

```typescript
import libEntry from 'libentry.so';

// 启动服务器
const success = libEntry.startServer('My Device', 53317);
console.log('Server started:', success);

// 扫描设备
const devicesJson = libEntry.scanDevices();
const devices = JSON.parse(devicesJson);
console.log('Found devices:', devices);

// 发送多播公告
libEntry.sendAnnouncement();

// 检查服务器状态
const running = libEntry.isServerRunning();
console.log('Server running:', running);

// 停止服务器
libEntry.stopServer();
```

## Rust FFI 函数列表

| 函数 | 说明 | 返回值 |
|------|------|--------|
| `localsend_start_server(alias, port)` | 启动服务器 | bool |
| `localsend_stop_server()` | 停止服务器 | void |
| `localsend_scan_devices()` | 扫描设备 | char* (JSON) |
| `localsend_get_network_info()` | 获取网络信息 | char* (JSON) |
| `localsend_send_request(ip, port, files)` | 发送文件请求 | bool |
| `localsend_send_announcement()` | 发送多播公告 | bool |
| `localsend_is_server_running()` | 检查服务器状态 | bool |
| `localsend_free_string(s)` | 释放字符串 | void |

## 调试

### 查看 Rust 日志

```rust
// 在 Rust 代码中添加日志
log::info!("Server started on port {}", port);
log::error!("Failed to bind socket: {}", e);
```

### 查看 C++ 日志

```cpp
// 在 C++ 代码中添加日志
#include <hilog/log.h>
OH_LOG_INFO(LOG_APP, "Server started: %{public}d", success);
```

## 常见问题

### Q: Rust 库找不到

```
Warning: Rust library not found at: .../liblocalsend_harmony.a
```

**解决方案**: 先运行 `./build_rust_simple.sh` 编译 Rust 库。

### Q: 链接错误

```
undefined reference to `localsend_start_server'
```

**解决方案**: 
1. 确保 Rust 库已编译
2. 检查 CMakeLists.txt 中的路径配置
3. 确保 `#include "localsend_rust.h"` 正确

### Q: HarmonyOS target 不可用

```
error: can't find crate for `std`
```

**解决方案**: 使用标准 Linux target 进行测试：
```bash
cargo build --release --target aarch64-unknown-linux-gnu
```

## 下一步

1. **集成 LocalSend 核心库**
   
   将 `localsend` crate 作为依赖添加到 `Cargo.toml`：
   ```toml
   [dependencies]
   localsend = { path = "../../../core" }
   ```

2. **实现完整的设备发现**
   
   参考 Flutter 版本的 `multicast_discovery.dart` 实现

3. **添加 HTTPS 支持**
   
   使用 `rustls` 或 `native-tls` crate

4. **实现文件传输**
   
   使用 `tokio` 异步 IO

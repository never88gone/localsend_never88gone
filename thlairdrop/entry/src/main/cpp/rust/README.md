# LocalSend Rust Core

这是 LocalSend HarmonyOS 版本的核心 Rust 库，提供设备发现和文件传输功能。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                    ArkTS (UI Layer)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  Index.ets  │  │ DeviceList  │  │ ServerStatus│      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Service Layer (ArkTS)                       │
│  ┌─────────────────────────────────────────────────┐    │
│  │           LocalSendService.ets                    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   NAPI (C++ Bridge)                      │
│  ┌─────────────────────────────────────────────────┐    │
│  │              localsend.cpp                        │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Rust Core (FFI)                        │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐           │
│  │ Discovery │  │  Server   │  │   Model   │           │
│  │  (UDP)    │  │  (HTTP)   │  │   (DTO)   │           │
│  └───────────┘  └───────────┘  └───────────┘           │
└─────────────────────────────────────────────────────────┘
```

## 目录结构

```
rust/
├── Cargo.toml              # Rust 依赖配置
├── cbindgen.toml           # C 头文件生成配置
└── src/
    ├── lib.rs              # FFI 导出入口
    ├── model/              # 数据模型
    │   ├── mod.rs
    │   ├── device.rs       # 设备模型
    │   └── dto.rs          # 数据传输对象
    ├── discovery/          # 设备发现
    │   ├── mod.rs
    │   └── multicast.rs    # UDP 多播发现
    ├── server/             # HTTP 服务器
    │   ├── mod.rs
    │   └── http.rs         # HTTP 端点处理
    └── util/               # 工具函数
        ├── mod.rs
        ├── fingerprint.rs  # 指纹生成
        └── network.rs      # 网络工具
```

## 功能模块

### 1. 设备发现 (Discovery)

使用 UDP 多播实现局域网设备发现：

- **多播地址**: `224.0.0.167:53317`
- **协议**: LocalSend 协议 v2.1
- **功能**:
  - 发送公告 (Announcement)
  - 监听其他设备公告
  - 自动响应公告

### 2. HTTP 服务器 (Server)

提供以下端点：

| 端点 | 方法 | 描述 |
|------|------|------|
| `/register` | POST | 设备注册 |
| `/request` | POST | 文件发送请求 |
| `/info` | GET | 设备信息 |

### 3. 数据模型 (Model)

- `Device`: 设备信息
- `MulticastDto`: 多播消息
- `RegisterDto`: 注册消息
- `SendRequestDto`: 发送请求

## 构建说明

### 前置要求

1. 安装 Rust: https://rustup.rs/
2. 添加 HarmonyOS 目标:
   ```bash
   rustup target add aarch64-unknown-linux-ohos
   rustup target add armv7-unknown-linux-ohos
   rustup target add x86_64-unknown-linux-ohos
   ```

### 构建

```bash
# 进入 cpp 目录
cd entry/src/main/cpp

# 构建所有目标
./build_rust.sh all

# 或构建特定目标
./build_rust.sh build aarch64  # arm64-v8a
./build_rust.sh build armv7    # armeabi-v7a
./build_rust.sh build x86_64   # x86_64
```

### 测试

```bash
./build_rust.sh test
```

## FFI 接口

所有导出的函数使用 `localsend_` 前缀：

```c
// 服务器控制
bool localsend_start_server(const char* alias, uint16_t port);
void localsend_stop_server();
bool localsend_is_server_running();

// 设备发现
char* localsend_scan_devices();
bool localsend_send_announcement();
int32_t localsend_get_device_count();

// 文件传输
bool localsend_send_request(const char* target_ip, uint16_t port, const char* files_json);
char* localsend_get_pending_requests();

// 内存管理
void localsend_free_string(char* s);
```

## 协议说明

LocalSend 使用以下协议：

### UDP 多播消息

```json
{
  "alias": "Device Name",
  "version": "2.1",
  "deviceModel": "HarmonyOS",
  "deviceType": "mobile",
  "fingerprint": "abc123...",
  "port": 53317,
  "protocol": "http",
  "download": false,
  "announcement": true,
  "announce": true
}
```

### HTTP 注册请求

POST `/register`

```json
{
  "alias": "Device Name",
  "version": "2.1",
  "deviceModel": "HarmonyOS",
  "deviceType": "mobile",
  "fingerprint": "abc123...",
  "port": 53317,
  "protocol": "http",
  "download": false
}
```

### 文件发送请求

POST `/request`

```json
{
  "files": [
    {
      "id": "file1",
      "fileName": "test.txt",
      "size": 1024,
      "fileType": "text/plain"
    }
  ],
  "requestId": "req123"
}
```

## 依赖说明

| 依赖 | 版本 | 用途 |
|------|------|------|
| tokio | 1.x | 异步运行时 |
| serde | 1.x | 序列化 |
| serde_json | 1.x | JSON 处理 |
| tiny_http | 0.12 | HTTP 服务器 |
| parking_lot | 0.12 | 高性能锁 |
| socket2 | 0.5 | Socket 配置 |

## 性能优化

- 使用 `parking_lot` 替代标准库锁，性能更好
- 静态链接减少运行时依赖
- LTO 优化减小二进制大小
- 单线程 HTTP 服务器，适合嵌入式场景

## 注意事项

1. **内存安全**: 所有返回的字符串必须使用 `localsend_free_string` 释放
2. **线程安全**: 所有函数都是线程安全的
3. **错误处理**: 返回 `false` 或 `null` 表示失败
4. **编码**: 所有字符串使用 UTF-8 编码

## License

MIT License

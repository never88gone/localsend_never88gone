/**
 * LocalSend Rust FFI Header
 * 
 * C bindings for LocalSend Rust library
 */

#ifndef LOCALSEND_RUST_H
#define LOCALSEND_RUST_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// 内存管理
// ============================================================================

/// 释放 Rust 分配的字符串
void localsend_rust_free_string(char* s);

// ============================================================================
// 服务器控制
// ============================================================================

/// 启动 LocalSend 服务器
/// @param alias 设备别名，如果为 NULL 则使用默认名称
/// @param port 监听端口，默认 53317
/// @return 成功返回 true
bool localsend_start_server(const char* alias, uint16_t port);

/// 停止 LocalSend 服务器
void localsend_stop_server(void);

/// 检查服务器是否运行
/// @return 运行中返回 true
bool localsend_is_server_running(void);

// ============================================================================
// 设备发现
// ============================================================================

/// 扫描局域网设备
/// @return JSON 格式的设备列表，需要调用 localsend_rust_free_string 释放
char* localsend_scan_devices(void);

/// 发送多播公告
/// @return 成功返回 true
bool localsend_send_announcement(void);

/// 获取已发现设备数量
/// @return 设备数量
int32_t localsend_get_device_count(void);

/// 获取已注册设备列表
/// @return JSON 格式的设备列表，需要调用 localsend_rust_free_string 释放
char* localsend_get_registered_devices(void);

// ============================================================================
// 网络信息
// ============================================================================

/// 获取本地网络信息
/// @return JSON 格式的网络信息，需要调用 localsend_rust_free_string 释放
char* localsend_get_network_info(void);

/// 获取设备指纹
/// @return 32 字符的十六进制指纹，需要调用 localsend_rust_free_string 释放
char* localsend_get_fingerprint(void);

/// 设置设备别名
/// @param alias 新的设备别名
/// @return 成功返回 true
bool localsend_set_alias(const char* alias);

// ============================================================================
// 文件传输
// ============================================================================

/// 发送文件请求到目标设备
/// @param target_ip 目标设备 IP 地址
/// @param port 目标设备端口
/// @param files_json JSON 格式的文件列表
/// @return 成功返回 true
bool localsend_send_request(const char* target_ip, uint16_t port, const char* files_json);

/// 获取待处理的文件请求
/// @return JSON 格式的请求列表，需要调用 localsend_rust_free_string 释放
char* localsend_get_pending_requests(void);

/// 接受文件传输请求
/// @param request_id 请求 ID
/// @param save_dir 保存目录
/// @return 成功返回 true
bool localsend_accept_request(const char* request_id, const char* save_dir);

/// 拒绝文件传输请求
/// @param request_id 请求 ID
/// @return 成功返回 true
bool localsend_reject_request(const char* request_id);

/// 获取接收进度
/// @param request_id 请求 ID
/// @return 0-100 的进度值，-1 表示错误
int32_t localsend_get_receive_progress(const char* request_id);

/// 取消文件传输
/// @param request_id 请求 ID
/// @return 成功返回 true
bool localsend_cancel_transfer(const char* request_id);

// ============================================================================
// 回调注册
// ============================================================================

/// 设备发现回调函数类型
typedef void (*LocalsendDeviceCallback)(const char* device_json);

/// 文件接收回调函数类型
typedef void (*LocalsendFileCallback)(const char* request_json);

/// 注册设备发现回调
void localsend_set_device_callback(LocalsendDeviceCallback callback);

/// 注册文件接收回调
void localsend_set_file_callback(LocalsendFileCallback callback);

// ============================================================================
// 测试函数
// ============================================================================

/// 测试函数，返回问候语
/// @return 字符串，需要调用 localsend_rust_free_string 释放
char* localsend_rust_hello(void);

#ifdef __cplusplus
}
#endif

#endif // LOCALSEND_RUST_H

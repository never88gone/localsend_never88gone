#include "napi/native_api.h"
#include "localsend_rust.h"
#include <string>
#include <cstring>
#include <uv.h>

// ============================================================================
// 全局回调句柄
// ============================================================================

static napi_threadsafe_function g_file_callback_fn = nullptr;
static napi_threadsafe_function g_device_callback_fn = nullptr;

/**
 * 线程安全函数的回调处理 (JS 线程执行)
 */
static void CallJsCallback(napi_env env, napi_value js_cb, void* context, void* data) {
    (void)context;
    char* json_data = static_cast<char*>(data);
    
    napi_value args[1];
    napi_create_string_utf8(env, json_data, NAPI_AUTO_LENGTH, &args[0]);
    
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    
    napi_value result;
    napi_call_function(env, undefined, js_cb, 1, args, &result);
    
    // 释放由 C++ 线程分配的字符串
    free(json_data);
}

/**
 * C 层触发的回调代理 (工作线程执行)
 */
static void OnNativeFileRequest(const char* request_json) {
    if (g_file_callback_fn) {
        char* data = strdup(request_json);
        napi_status status = napi_call_threadsafe_function(g_file_callback_fn, data, napi_tsfn_nonblocking);
        if (status != napi_ok) {
            free(data);
        }
    }
}

static void OnNativeDeviceDiscovered(const char* device_json) {
    if (g_device_callback_fn) {
        char* data = strdup(device_json);
        napi_status status = napi_call_threadsafe_function(g_device_callback_fn, data, napi_tsfn_nonblocking);
        if (status != napi_ok) {
            free(data);
        }
    }
}

static void OnNativeProgress(const char* request_id, int32_t progress) {
    if (g_file_callback_fn) { // 这里复用了文件回调的线程安全函数，或者新建一个
        // 最好新建一个，但为了简化先合并
    }
}

/**
 * 专门处理进度的回调处理
 */
static void CallProgressJsCallback(napi_env env, napi_value js_cb, void* context, void* data) {
    (void)context;
    // 进度数据通常较小，我们可以直接传结构体，但为了统一还是传字符串或由 data 转换
    struct ProgressData {
        char id[128];
        int32_t progress;
    };
    ProgressData* pdata = static_cast<ProgressData*>(data);
    
    napi_value args[2];
    napi_create_string_utf8(env, pdata->id, NAPI_AUTO_LENGTH, &args[0]);
    napi_create_int32(env, pdata->progress, &args[1]);
    
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    
    napi_value result;
    napi_call_function(env, undefined, js_cb, 2, args, &result);
    
    delete pdata;
}

static napi_threadsafe_function g_progress_callback_fn = nullptr;

static void OnNativeProgressReal(const char* request_id, int32_t progress) {
    if (g_progress_callback_fn) {
        struct ProgressData {
            char id[128];
            int32_t progress;
        };
        ProgressData* data = new ProgressData();
        strncpy(data->id, request_id, 127);
        data->progress = progress;
        napi_status status = napi_call_threadsafe_function(g_progress_callback_fn, data, napi_tsfn_nonblocking);
        if (status != napi_ok) {
            delete data;
        }
    }
}

/**
 * 设置进度回调
 */
static napi_value SetProgressCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_value work_name;
    napi_create_string_utf8(env, "ProgressCallback", NAPI_AUTO_LENGTH, &work_name);

    if (g_progress_callback_fn) {
        napi_release_threadsafe_function(g_progress_callback_fn, napi_tsfn_release);
    }

    napi_create_threadsafe_function(env, args[0], nullptr, work_name, 0, 1, nullptr, nullptr, nullptr, CallProgressJsCallback, &g_progress_callback_fn);
    
    // 注册给底层 C++
    localsend_set_progress_callback(OnNativeProgressReal);

    return nullptr;
}

// ============================================================================
// NAPI 函数实现
// ============================================================================

/**
 * 设置文件请求回调
 */
static napi_value SetFileCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_value work_name;
    napi_create_string_utf8(env, "FileRequestCallback", NAPI_AUTO_LENGTH, &work_name);

    if (g_file_callback_fn) {
        napi_release_threadsafe_function(g_file_callback_fn, napi_tsfn_release);
    }

    napi_create_threadsafe_function(env, args[0], nullptr, work_name, 0, 1, nullptr, nullptr, nullptr, CallJsCallback, &g_file_callback_fn);
    
    // 注册给底层 C++
    localsend_set_file_callback(OnNativeFileRequest);

    return nullptr;
}

/**
 * 设置设备发现回调
 */
static napi_value SetDeviceCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_value work_name;
    napi_create_string_utf8(env, "DeviceDiscoveryCallback", NAPI_AUTO_LENGTH, &work_name);

    if (g_device_callback_fn) {
        napi_release_threadsafe_function(g_device_callback_fn, napi_tsfn_release);
    }

    napi_create_threadsafe_function(env, args[0], nullptr, work_name, 0, 1, nullptr, nullptr, nullptr, CallJsCallback, &g_device_callback_fn);
    
    // 注册给底层 C++
    localsend_set_device_callback(OnNativeDeviceDiscovered);

    return nullptr;
}

/**
 * 启动 LocalSend 服务器
 */
static napi_value StartServer(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char alias[256] = {0};
    size_t alias_len = 0;
    if (argc >= 1 && args[0] != nullptr) {
        napi_get_value_string_utf8(env, args[0], alias, sizeof(alias), &alias_len);
    }

    int32_t port = 53317;
    if (argc >= 2 && args[1] != nullptr) {
        napi_get_value_int32(env, args[1], &port);
    }

    char local_ip[128] = {0};
    size_t ip_len = 0;
    if (argc >= 3 && args[2] != nullptr) {
        napi_get_value_string_utf8(env, args[2], local_ip, sizeof(local_ip), &ip_len);
    }

    bool success = localsend_start_server(alias, static_cast<uint16_t>(port), local_ip);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 停止 LocalSend 服务器
 */
static napi_value StopServer(napi_env env, napi_callback_info info) {
    (void)env;
    (void)info;
    localsend_stop_server();
    return nullptr;
}

/**
 * 扫描局域网设备
 */
static napi_value ScanDevices(napi_env env, napi_callback_info info) {
    (void)info;
    char* devices_json = localsend_scan_devices();
    
    napi_value result;
    napi_create_string_utf8(env, devices_json, NAPI_AUTO_LENGTH, &result);
    
    localsend_rust_free_string(devices_json);
    return result;
}

/**
 * 获取本地网络信息
 */
static napi_value GetLocalNetworkInfo(napi_env env, napi_callback_info info) {
    (void)info;
    char* network_json = localsend_get_network_info();
    
    napi_value result;
    napi_create_string_utf8(env, network_json, NAPI_AUTO_LENGTH, &result);
    
    localsend_rust_free_string(network_json);
    return result;
}

/**
 * 发送文件请求
 */
static napi_value SendRequest(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char target_ip[64] = {0};
    size_t ip_len = 0;
    napi_get_value_string_utf8(env, args[0], target_ip, sizeof(target_ip), &ip_len);

    int32_t port = 53317;
    napi_get_value_int32(env, args[1], &port);

    size_t files_len = 0;
    napi_get_value_string_utf8(env, args[2], nullptr, 0, &files_len);
    char* files_json = new char[files_len + 1];
    napi_get_value_string_utf8(env, args[2], files_json, files_len + 1, &files_len);

    bool success = localsend_send_request(target_ip, static_cast<uint16_t>(port), files_json);

    delete[] files_json;

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 发送多播公告
 */
static napi_value SendAnnouncement(napi_env env, napi_callback_info info) {
    (void)info;
    bool success = localsend_send_announcement();
    
    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 检查服务器是否运行
 */
static napi_value IsServerRunning(napi_env env, napi_callback_info info) {
    (void)info;
    bool running = localsend_is_server_running();
    
    napi_value result;
    napi_get_boolean(env, running, &result);
    return result;
}

/**
 * 获取已发现设备数量
 */
static napi_value GetDeviceCount(napi_env env, napi_callback_info info) {
    (void)info;
    int32_t count = localsend_get_device_count();
    
    napi_value result;
    napi_create_int32(env, count, &result);
    return result;
}

/**
 * 获取已注册设备
 */
static napi_value GetRegisteredDevices(napi_env env, napi_callback_info info) {
    (void)info;
    char* devices_json = localsend_get_registered_devices();
    
    napi_value result;
    napi_create_string_utf8(env, devices_json, NAPI_AUTO_LENGTH, &result);
    
    localsend_rust_free_string(devices_json);
    return result;
}

/**
 * 获取待处理请求
 */
static napi_value GetPendingRequests(napi_env env, napi_callback_info info) {
    (void)info;
    char* requests_json = localsend_get_pending_requests();
    
    napi_value result;
    napi_create_string_utf8(env, requests_json, NAPI_AUTO_LENGTH, &result);
    
    localsend_rust_free_string(requests_json);
    return result;
}

/**
 * 设置设备别名
 */
static napi_value SetAlias(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char alias[256] = {0};
    size_t alias_len = 0;
    napi_get_value_string_utf8(env, args[0], alias, sizeof(alias), &alias_len);

    bool success = localsend_set_alias(alias);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 设置接收端 PIN 码
 */
static napi_value SetPinCode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char pin[64] = {0};
    size_t pin_len = 0;
    napi_get_value_string_utf8(env, args[0], pin, sizeof(pin), &pin_len);

    localsend_set_pin_code(pin);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

/**
 * 获取设备指纹
 */
static napi_value GetFingerprint(napi_env env, napi_callback_info info) {
    (void)info;
    char* fingerprint = localsend_get_fingerprint();
    
    napi_value result;
    napi_create_string_utf8(env, fingerprint, NAPI_AUTO_LENGTH, &result);
    
    localsend_rust_free_string(fingerprint);
    return result;
}

/**
 * 接受文件请求
 */
static napi_value AcceptRequest(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char request_id[128] = {0};
    char save_dir[512] = {0};
    size_t len = 0;
    
    napi_get_value_string_utf8(env, args[0], request_id, sizeof(request_id), &len);
    napi_get_value_string_utf8(env, args[1], save_dir, sizeof(save_dir), &len);

    bool success = localsend_accept_request(request_id, save_dir);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 拒绝文件请求
 */
static napi_value RejectRequest(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char request_id[128] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], request_id, sizeof(request_id), &len);

    bool success = localsend_reject_request(request_id);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

/**
 * 获取接收进度
 */
static napi_value GetReceiveProgress(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char request_id[128] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], request_id, sizeof(request_id), &len);

    int32_t progress = localsend_get_receive_progress(request_id);

    napi_value result;
    napi_create_int32(env, progress, &result);
    return result;
}

/**
 * 取消传输
 */
static napi_value CancelTransfer(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char request_id[128] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], request_id, sizeof(request_id), &len);

    bool success = localsend_cancel_transfer(request_id);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

// ============================================================================
// 模块注册
// ============================================================================

EXTERN_C_START

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // 服务器控制
        {"startServer", nullptr, StartServer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopServer", nullptr, StopServer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isServerRunning", nullptr, IsServerRunning, nullptr, nullptr, nullptr, napi_default, nullptr},
        
        // 设备发现
        {"scanDevices", nullptr, ScanDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sendAnnouncement", nullptr, SendAnnouncement, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getDeviceCount", nullptr, GetDeviceCount, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getRegisteredDevices", nullptr, GetRegisteredDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setDeviceCallback", nullptr, SetDeviceCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        
        // 网络信息
        {"getLocalNetworkInfo", nullptr, GetLocalNetworkInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getFingerprint", nullptr, GetFingerprint, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setAlias", nullptr, SetAlias, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setPinCode", nullptr, SetPinCode, nullptr, nullptr, nullptr, napi_default, nullptr},
        
        // 文件传输
        {"sendRequest", nullptr, SendRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getPendingRequests", nullptr, GetPendingRequests, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"acceptRequest", nullptr, AcceptRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"rejectRequest", nullptr, RejectRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getReceiveProgress", nullptr, GetReceiveProgress, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cancelTransfer", nullptr, CancelTransfer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setFileCallback", nullptr, SetFileCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setProgressCallback", nullptr, SetProgressCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&demoModule);
}

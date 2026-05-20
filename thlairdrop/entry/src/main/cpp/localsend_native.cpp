/**
 * LocalSend Native Implementation (C++)
 * 
 * 完整实现，包含 UDP 多播发现和 HTTP 服务器
 */

#include "localsend_rust.h"
#include <cstring>
#include <cstdlib>
#include <string>
#include <sstream>
#include <vector>
#include <map>
#include <mutex>
#include <thread>
#include <chrono>
#include <random>
#include <atomic>
#include <functional>
#include <iomanip>
#include <cstdio>
#include <condition_variable>

// HarmonyOS socket 头文件
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <hilog/log.h>

// ============================================================================
// 日志定义
// ============================================================================
#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0001
#define LOG_TAG "LocalSendNative"

#define LOGI(...) ((void)OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGE(...) ((void)OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGW(...) ((void)OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

// ============================================================================
// 常量定义
// ============================================================================

namespace {
    constexpr const char* MULTICAST_GROUP = "224.0.0.167";
    constexpr uint16_t MULTICAST_PORT = 53317;
    constexpr uint16_t HTTP_PORT = 53317;
    constexpr size_t BUFFER_SIZE = 65536;
    constexpr int DISCOVERY_TIMEOUT_MS = 3000;
}

// 前置声明
static std::string extract_query_param(const std::string& query, const std::string& key);

// ============================================================================
// 全局状态
// ============================================================================

// 单个文件项结构体
struct FileItem {
    std::string id;
    std::string name;
    int64_t size;
    std::string type;
    std::string preview;
};

// 文件请求结构体
struct FileRequest {
    std::string id;
    std::string sender_ip;
    std::string sender_alias;
    std::vector<FileItem> file_items; // 详细文件信息
    std::vector<std::string> file_paths; // 用于发送时的本地路径
    std::vector<int> file_fds;           // 用于零拷贝发送的文件描述符列表
    std::string save_dir;
    int64_t total_size;
    std::atomic<int32_t> progress;
    std::atomic<bool> is_cancelled;
    bool accepted;
    bool is_sending; // true: 发送, false: 接收
    std::chrono::steady_clock::time_point creation_time;

    FileRequest() : progress(0), is_cancelled(false), accepted(false), is_sending(false), 
                    creation_time(std::chrono::steady_clock::now()) {}
    
    // 析构函数自动释放所有未关闭的 FD
    ~FileRequest() {
        for (int fd : file_fds) {
            if (fd >= 0) {
                close(fd);
            }
        }
    }
    
    // 移动构造函数
    FileRequest(FileRequest&& other) noexcept :
        id(std::move(other.id)),
        sender_ip(std::move(other.sender_ip)),
        sender_alias(std::move(other.sender_alias)),
        file_items(std::move(other.file_items)),
        file_paths(std::move(other.file_paths)),
        file_fds(std::move(other.file_fds)),
        save_dir(std::move(other.save_dir)),
        total_size(other.total_size),
        progress(other.progress.load()),
        is_cancelled(other.is_cancelled.load()),
        accepted(other.accepted),
        is_sending(other.is_sending),
        creation_time(other.creation_time) {
            other.file_fds.clear();
        }

    // 移动赋值运算符
    FileRequest& operator=(FileRequest&& other) noexcept {
        if (this != &other) {
            // 释放当前可能存有的 FD
            for (int fd : file_fds) {
                if (fd >= 0) close(fd);
            }
            id = std::move(other.id);
            sender_ip = std::move(other.sender_ip);
            sender_alias = std::move(other.sender_alias);
            file_items = std::move(other.file_items);
            file_paths = std::move(other.file_paths);
            file_fds = std::move(other.file_fds);
            other.file_fds.clear();
            save_dir = std::move(other.save_dir);
            total_size = other.total_size;
            progress.store(other.progress.load());
            is_cancelled.store(other.is_cancelled.load());
            accepted = other.accepted;
            is_sending = other.is_sending;
        }
        return *this;
    }

    // 禁用拷贝
    FileRequest(const FileRequest&) = delete;
    FileRequest& operator=(const FileRequest&) = delete;
};

// 回调函数类型
typedef void (*LocalsendDeviceCallback)(const char* device_json);
typedef void (*LocalsendFileCallback)(const char* request_json);

static std::mutex g_mutex;
static std::condition_variable g_cv;
static std::atomic<bool> g_server_running{false};
static std::atomic<bool> g_discovery_running{false};
static std::string g_device_alias = "HarmonyOS Device";
static uint16_t g_server_port = HTTP_PORT;
static std::string g_device_fingerprint;
static std::string g_local_ip;
static std::map<std::string, std::string> g_discovered_devices;
static std::map<std::string, std::chrono::steady_clock::time_point> g_device_timestamps;
static std::map<std::string, FileRequest> g_pending_requests;
static std::thread g_discovery_thread;
static std::thread g_http_thread;
static int g_multicast_socket = -1;
static int g_http_socket = -1;
static LocalsendDeviceCallback g_device_callback = nullptr;
static LocalsendFileCallback g_file_callback = nullptr;
static LocalsendProgressCallback g_progress_callback = nullptr;
static std::string g_pin_code = "";

struct PinAttempt {
    int count = 0;
    std::chrono::steady_clock::time_point last_attempt_time;
};
static std::map<std::string, PinAttempt> g_pin_attempts;

static void trigger_device_callback() {
    if (g_device_callback) {
        std::string json_str;
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            std::ostringstream json;
            json << "[";
            bool first = true;
            for (auto it = g_discovered_devices.begin(); it != g_discovered_devices.end(); ++it) {
                if (!first) json << ",";
                json << it->second;
                first = false;
            }
            json << "]";
            json_str = json.str();
        }
        g_device_callback(json_str.c_str());
    }
}

static void cleanup_stale_devices() {
    auto now = std::chrono::steady_clock::now();
    bool changed = false;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto it = g_device_timestamps.begin(); it != g_device_timestamps.end(); ) {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - it->second).count();
            if (elapsed > 40) { // 40 seconds TTL
                g_discovered_devices.erase(it->first);
                it = g_device_timestamps.erase(it);
                changed = true;
            } else {
                ++it;
            }
        }
    }
    if (changed) {
        trigger_device_callback();
    }
}

static void trigger_progress(const std::string& id, int32_t progress) {
    if (g_progress_callback) {
        g_progress_callback(id.c_str(), progress);
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

static std::string generate_fingerprint() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 15);
    
    const char* hex = "0123456789abcdef";
    std::string result;
    result.reserve(32);
    
    for (int i = 0; i < 32; ++i) {
        result += hex[dis(gen)];
    }
    return result;
}

static char* alloc_string(const std::string& s) {
    char* result = static_cast<char*>(malloc(s.size() + 1));
    std::memcpy(result, s.c_str(), s.size() + 1);
    return result;
}

static void set_socket_timeouts(int sock, int seconds) {
    struct timeval tv;
    tv.tv_sec = seconds;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&tv, sizeof(tv));
}

static std::string sanitize_filename(const std::string& filename) {
    std::string safe_name = filename;
    // 移除路径分隔符，防止目录遍历
    size_t pos;
    while ((pos = safe_name.find_first_of("/\\")) != std::string::npos) {
        safe_name[pos] = '_';
    }
    // 移除 ".." 
    while ((pos = safe_name.find("..")) != std::string::npos) {
        safe_name.replace(pos, 2, "__");
    }
    return safe_name;
}

static bool ensure_directory(const std::string& path) {
    if (path.empty()) {
        LOGE("ensure_directory: path is empty!");
        return false;
    }
    struct stat st = {0};
    if (stat(path.c_str(), &st) == 0) {
        if (S_ISDIR(st.st_mode)) {
            return true;
        }
        LOGE("ensure_directory: %{public}s exists but is not a directory!", path.c_str());
        return false;
    }
    
    // 递归创建目录
    std::string current_path = "";
    std::string token;
    std::istringstream ss(path);
    if (path[0] == '/') {
        current_path = "/";
    }
    while (std::getline(ss, token, '/')) {
        if (token.empty()) continue;
        current_path += token;
        if (stat(current_path.c_str(), &st) == -1) {
            if (mkdir(current_path.c_str(), 0777) != 0 && errno != EEXIST) {
                LOGE("Failed to create directory: %{public}s, error: %d", current_path.c_str(), errno);
                return false;
            }
        }
        current_path += "/";
    }
    return true;
}

static std::string get_unique_filename(const std::string& directory, const std::string& filename) {
    std::string name = filename;
    std::string ext = "";
    size_t dot_pos = filename.find_last_of('.');
    if (dot_pos != std::string::npos && dot_pos > 0) {
        name = filename.substr(0, dot_pos);
        ext = filename.substr(dot_pos);
    }
    
    std::string full_path = directory + "/" + filename;
    int counter = 1;
    struct stat st;
    while (stat(full_path.c_str(), &st) == 0) {
        std::ostringstream new_name;
        new_name << name << " (" << counter << ")" << ext;
        full_path = directory + "/" + new_name.str();
        counter++;
    }
    return full_path;
}

static std::string get_all_ips() {
    struct ifaddrs *ifAddrStruct = NULL;
    struct ifaddrs *ifa = NULL;
    std::string wlan_ips;
    std::string eth_ips;
    std::string other_ips;

    if (getifaddrs(&ifAddrStruct) == -1) {
        LOGE("getifaddrs failed");
        return "127.0.0.1";
    }

    for (ifa = ifAddrStruct; ifa != NULL; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
        
        void* tmpAddrPtr = &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr;
        char addressBuffer[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, tmpAddrPtr, addressBuffer, INET_ADDRSTRLEN);
        
        std::string name(ifa->ifa_name);
        // 过滤回环和虚拟网卡
        if (name != "lo" && name.find("docker") == std::string::npos && name.find("vbox") == std::string::npos) {
            std::string lower_name = name;
            for (char &c : lower_name) {
                if (c >= 'A' && c <= 'Z') c = c - 'A' + 'a';
            }
            
            if (lower_name.find("wlan") != std::string::npos) {
                if (!wlan_ips.empty()) wlan_ips += ",";
                wlan_ips += addressBuffer;
            } else if (lower_name.find("eth") != std::string::npos) {
                if (!eth_ips.empty()) eth_ips += ",";
                eth_ips += addressBuffer;
            } else {
                if (!other_ips.empty()) other_ips += ",";
                other_ips += addressBuffer;
            }
        }
    }
    if (ifAddrStruct != NULL) freeifaddrs(ifAddrStruct);
    
    // 优先顺序: wlan > eth > 其他
    std::string result;
    if (!wlan_ips.empty()) {
        result = wlan_ips;
    } else if (!eth_ips.empty()) {
        result = eth_ips;
    } else {
        result = other_ips;
    }
    
    return result.empty() ? "127.0.0.1" : result;
}

static std::string get_local_ip() {
    std::string all = get_all_ips();
    size_t pos = all.find(',');
    return (pos == std::string::npos) ? all : all.substr(0, pos);
}

static std::string url_encode(const std::string& s) {
    std::ostringstream result;
    for (char c : s) {
        if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            result << c;
        } else {
            result << '%' << std::uppercase << std::hex << (int)(unsigned char)c;
        }
    }
    return result.str();
}

static std::string json_escape(const std::string& s) {
    std::ostringstream result;
    for (char c : s) {
        switch (c) {
            case '"': result << "\\\""; break;
            case '\\': result << "\\\\"; break;
            case '\b': result << "\\b"; break;
            case '\f': result << "\\f"; break;
            case '\n': result << "\\n"; break;
            case '\r': result << "\\r"; break;
            case '\t': result << "\\t"; break;
            default:
                if ('\x00' <= c && c <= '\x1f') {
                    result << "\\u" << std::hex << std::setw(4) << std::setfill('0') << (int)c;
                } else {
                    result << c;
                }
        }
    }
    return result.str();
}

// ============================================================================
// UDP 多播发现
// ============================================================================

static bool setup_multicast_socket() {
    g_multicast_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (g_multicast_socket < 0) {
        return false;
    }
    
    // 允许地址重用
    int reuse = 1;
    setsockopt(g_multicast_socket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    // 绑定端口
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(MULTICAST_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(g_multicast_socket, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(g_multicast_socket);
        g_multicast_socket = -1;
        return false;
    }
    
    // 设置多播发送接口
    if (!g_local_ip.empty() && g_local_ip != "127.0.0.1") {
        struct in_addr out_addr;
        if (inet_pton(AF_INET, g_local_ip.c_str(), &out_addr) > 0) {
            setsockopt(g_multicast_socket, IPPROTO_IP, IP_MULTICAST_IF, &out_addr, sizeof(out_addr));
        }
    }
    
    // 加入多播组
    struct ip_mreq mreq;
    memset(&mreq, 0, sizeof(mreq));
    inet_pton(AF_INET, MULTICAST_GROUP, &mreq.imr_multiaddr);
    if (!g_local_ip.empty() && g_local_ip != "127.0.0.1") {
        inet_pton(AF_INET, g_local_ip.c_str(), &mreq.imr_interface.s_addr);
    } else {
        mreq.imr_interface.s_addr = INADDR_ANY;
    }
    
    if (setsockopt(g_multicast_socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq)) < 0) {
        close(g_multicast_socket);
        g_multicast_socket = -1;
        return false;
    }
    
    return true;
}

static std::string build_device_info_json(bool include_announce) {
    std::ostringstream json;
    json << "{";
    json << "\"alias\":\"" << json_escape(g_device_alias) << "\",";
    json << "\"version\":\"2.0\",";
    json << "\"deviceModel\":\"HarmonyOS\",";
    json << "\"deviceType\":\"mobile\",";
    json << "\"fingerprint\":\"" << g_device_fingerprint << "\",";
    json << "\"port\":" << g_server_port << ",";
    json << "\"protocol\":\"http\",";
    json << "\"download\":true";
    if (include_announce) {
        json << ",\"announce\":true";
    }
    json << "}";
    return json.str();
}

static void send_announcement() {
    if (g_multicast_socket < 0) return;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    std::string message = build_device_info_json(true);
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(MULTICAST_PORT);
    inet_pton(AF_INET, MULTICAST_GROUP, &addr.sin_addr);
    
    sendto(g_multicast_socket, message.c_str(), message.size(), 0,
           (struct sockaddr*)&addr, sizeof(addr));
}

static void discovery_loop() {
    char buffer[BUFFER_SIZE];
    struct sockaddr_in sender_addr;
    socklen_t sender_len = sizeof(sender_addr);
    
    while (g_discovery_running) {
        struct pollfd pfd;
        pfd.fd = g_multicast_socket;
        pfd.events = POLLIN;
        
        int ret = poll(&pfd, 1, 1000);
        if (ret <= 0) {
            cleanup_stale_devices();
            continue;
        }
        
        ssize_t len = recvfrom(g_multicast_socket, buffer, BUFFER_SIZE - 1, 0,
                               (struct sockaddr*)&sender_addr, &sender_len);
        if (len <= 0) continue;
        
        buffer[len] = '\0';
        
        // 获取发送者 IP
        char sender_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &sender_addr.sin_addr, sender_ip, INET_ADDRSTRLEN);
        
        // 忽略自己的消息
        if (std::string(sender_ip) == g_local_ip) continue;
        
        // 解析设备信息并存储
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            std::string device_json = buffer;
            size_t brace_pos = device_json.find('{');
            if (brace_pos != std::string::npos) {
                device_json.insert(brace_pos + 1, "\"address\":\"" + std::string(sender_ip) + "\",\"ip\":\"" + std::string(sender_ip) + "\",");
            }
            g_discovered_devices[sender_ip] = device_json;
            g_device_timestamps[sender_ip] = std::chrono::steady_clock::now();
        }
        trigger_device_callback();
    }
}

// ============================================================================
// HTTP 服务器
// ============================================================================

static std::string http_response(int status, const std::string& body, const std::string& content_type = "application/json") {
    std::ostringstream response;
    response << "HTTP/1.1 " << status << " OK\r\n";
    response << "Content-Type: " << content_type << "\r\n";
    response << "Content-Length: " << body.size() << "\r\n";
    response << "Access-Control-Allow-Origin: *\r\n";
    response << "Connection: close\r\n";
    response << "\r\n";
    response << body;
    return response.str();
}

static std::string handle_info_request() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return http_response(200, build_device_info_json(false));
}

// ============================================================================
// 文件传输处理
// ============================================================================

// 简单的 JSON 解析辅助函数
static std::string json_extract_string(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    
    pos += search.length();
    size_t colon_pos = json.find(':', pos);
    if (colon_pos == std::string::npos) return "";
    
    pos = colon_pos + 1;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')) {
        pos++;
    }
    
    if (pos >= json.size() || json[pos] != '"') return "";
    pos++; // 跳过开引号
    
    size_t end = json.find('"', pos);
    if (end == std::string::npos) return "";
    
    return json.substr(pos, end - pos);
}

static int64_t json_extract_number(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return 0;
    
    pos += search.length();
    size_t colon_pos = json.find(':', pos);
    if (colon_pos == std::string::npos) return 0;
    
    pos = colon_pos + 1;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')) {
        pos++;
    }
    
    if (pos >= json.size()) return 0;
    try {
        return std::stoll(json.substr(pos));
    } catch (...) {
        return 0;
    }
}

static std::string generate_request_id() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 999999);
    
    std::ostringstream id;
    id << "req-" << std::setw(6) << std::setfill('0') << dis(gen);
    return id.str();
}

static std::string handle_prepare_upload(const std::string& body, const std::string& sender_ip) {
    // LocalSend v2 协议: alias 嵌套在 "info" 对象中
    // 优先从 info.alias 中取，再回退到顶层 sender_alias / alias
    std::string sender_alias;

    // 尝试解析 "info": { ... "alias": "xxx" ... }
    size_t info_pos = body.find("\"info\":");
    if (info_pos != std::string::npos) {
        size_t info_brace = body.find("{", info_pos);
        if (info_brace != std::string::npos) {
            // 找到 info 对象的结束 }（简单查找，不考虑超深嵌套）
            size_t info_end = body.find("}", info_brace);
            if (info_end != std::string::npos) {
                std::string info_obj = body.substr(info_brace, info_end - info_brace + 1);
                sender_alias = json_extract_string(info_obj, "alias");
            }
        }
    }

    // 回退：直接从顶层解析
    if (sender_alias.empty()) sender_alias = json_extract_string(body, "sender_alias");
    if (sender_alias.empty()) sender_alias = json_extract_string(body, "alias");
    if (sender_alias.empty()) sender_alias = sender_ip;

    // 生成请求 ID
    std::string request_id = generate_request_id();

    FileRequest fr;
    fr.id = request_id;
    fr.sender_ip = sender_ip;
    fr.sender_alias = sender_alias;
    fr.total_size = 0;
    fr.progress = 0;
    fr.accepted = false;
    fr.is_sending = false;

    // -------------------------------------------------------------------------
    // 解析 files 字段
    // LocalSend v2 格式:  "files": { "fileId": { ... }, "fileId2": { ... } }
    // LocalSend v1 格式:  "files": [ { ... }, { ... } ]
    // -------------------------------------------------------------------------
    size_t files_key_pos = body.find("\"files\":");
    if (files_key_pos != std::string::npos) {
        size_t value_start = body.find_first_not_of(" \t\r\n", files_key_pos + 8); // 跳过 "files":
        if (value_start != std::string::npos) {
            char first_char = body[value_start];

            if (first_char == '{') {
                // === v2 格式: map 对象 ===
                // 格式: { "fileId": { "id":..., "fileName":..., "size":..., "fileType":... }, ... }
                // 需要找到外层 {} 的匹配结束位置
                int brace_depth = 0;
                size_t map_start = value_start;
                size_t map_end = std::string::npos;
                for (size_t i = map_start; i < body.size(); ++i) {
                    if (body[i] == '{') brace_depth++;
                    else if (body[i] == '}') {
                        brace_depth--;
                        if (brace_depth == 0) { map_end = i; break; }
                    }
                }
                if (map_end != std::string::npos) {
                    // 在外层 { } 内，每遇到一个 value 对象 { ... }（depth-2层），就是一个文件
                    size_t pos = map_start + 1; // 跳过外层 {
                    while (pos < map_end) {
                        // 跳到下一个 key（字符串），格式 "fileId":
                        size_t key_quote = body.find('"', pos);
                        if (key_quote == std::string::npos || key_quote >= map_end) break;

                        // 找 key 的结束 "
                        size_t key_end = body.find('"', key_quote + 1);
                        if (key_end == std::string::npos || key_end >= map_end) break;

                        // 找冒号后的 {
                        size_t colon_pos = body.find(':', key_end + 1);
                        if (colon_pos == std::string::npos || colon_pos >= map_end) break;

                        size_t obj_start = body.find('{', colon_pos + 1);
                        if (obj_start == std::string::npos || obj_start >= map_end) break;

                        // 找文件对象的匹配 }
                        int depth = 0;
                        size_t obj_end = std::string::npos;
                        for (size_t i = obj_start; i < map_end; ++i) {
                            if (body[i] == '{') depth++;
                            else if (body[i] == '}') {
                                depth--;
                                if (depth == 0) { obj_end = i; break; }
                            }
                        }
                        if (obj_end == std::string::npos) break;

                        std::string obj_str = body.substr(obj_start, obj_end - obj_start + 1);

                        FileItem item;
                        // id 优先使用 map 的 key（fileId），再用对象内的 id
                        item.id = body.substr(key_quote + 1, key_end - key_quote - 1);
                        // fileName
                        item.name = json_extract_string(obj_str, "fileName");
                        if (item.name.empty()) item.name = json_extract_string(obj_str, "name");
                        // fileType
                        item.type = json_extract_string(obj_str, "fileType");
                        // size
                        item.size = json_extract_number(obj_str, "size");

                        fr.total_size += item.size;
                        fr.file_items.push_back(std::move(item));

                        pos = obj_end + 1;
                    }
                }

            } else if (first_char == '[') {
                // === v1 格式: 数组 ===
                size_t array_start = value_start;
                // 找到数组结束 ]
                int bracket_depth = 0;
                size_t array_end = std::string::npos;
                for (size_t i = array_start; i < body.size(); ++i) {
                    if (body[i] == '[') bracket_depth++;
                    else if (body[i] == ']') {
                        bracket_depth--;
                        if (bracket_depth == 0) { array_end = i; break; }
                    }
                }
                if (array_end != std::string::npos) {
                    size_t pos = array_start + 1;
                    while (pos < array_end) {
                        size_t obj_start = body.find('{', pos);
                        if (obj_start == std::string::npos || obj_start >= array_end) break;

                        int depth = 0;
                        size_t obj_end = std::string::npos;
                        for (size_t i = obj_start; i < array_end; ++i) {
                            if (body[i] == '{') depth++;
                            else if (body[i] == '}') {
                                depth--;
                                if (depth == 0) { obj_end = i; break; }
                            }
                        }
                        if (obj_end == std::string::npos) break;

                        std::string obj_str = body.substr(obj_start, obj_end - obj_start + 1);

                        FileItem item;
                        item.id = json_extract_string(obj_str, "id");
                        item.name = json_extract_string(obj_str, "fileName");
                        if (item.name.empty()) item.name = json_extract_string(obj_str, "name");
                        item.type = json_extract_string(obj_str, "fileType");

                        item.size = json_extract_number(obj_str, "size");

                        fr.total_size += item.size;
                        fr.file_items.push_back(std::move(item));

                        pos = obj_end + 1;
                    }
                }
            }
        }
    }

    // 触发回调
    if (g_file_callback) {
        std::ostringstream callback_json;
        callback_json << "{";
        callback_json << "\"id\":\"" << request_id << "\",";
        callback_json << "\"sender_ip\":\"" << sender_ip << "\",";
        callback_json << "\"sender_alias\":\"" << json_escape(sender_alias) << "\",";
        callback_json << "\"file_count\":" << fr.file_items.size() << ",";
        callback_json << "\"total_size\":" << fr.total_size << ",";
        callback_json << "\"files\":[";
        for (size_t i = 0; i < fr.file_items.size(); ++i) {
            if (i > 0) callback_json << ",";
            callback_json << "{";
            callback_json << "\"id\":\"" << fr.file_items[i].id << "\",";
            callback_json << "\"fileName\":\"" << json_escape(fr.file_items[i].name) << "\",";
            callback_json << "\"size\":" << fr.file_items[i].size << ",";
            callback_json << "\"fileType\":\"" << fr.file_items[i].type << "\"";
            callback_json << "}";
        }
        callback_json << "]";
        callback_json << "}";
        g_file_callback(callback_json.str().c_str());
    }

    // 存储请求 (MOVE MUST BE LAST)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_pending_requests[request_id] = std::move(fr);
    }

    // 阻塞等待用户接受或拒绝（或者超时）
    std::unique_lock<std::mutex> u_lock(g_mutex);
    bool status = g_cv.wait_for(u_lock, std::chrono::seconds(60), [request_id]() {
        auto it = g_pending_requests.find(request_id);
        if (it == g_pending_requests.end()) return true; // 被删了，视为拒绝/退出
        return it->second.accepted || it->second.is_cancelled;
    });

    // 唤醒后，检查最终状态
    auto it = g_pending_requests.find(request_id);
    if (!status || it == g_pending_requests.end() || it->second.is_cancelled || !it->second.accepted) {
        LOGW("prepare_upload rejected or timed out for session: %s", request_id.c_str());
        if (it != g_pending_requests.end()) {
            g_pending_requests.erase(it);
        }
        return http_response(403, "{\"error\":\"Request rejected\"}");
    }

    // 返回响应
    std::ostringstream response;
    response << "{";
    response << "\"sessionId\":\"" << request_id << "\",";
    response << "\"files\":{";

    // 为每个文件生成 token
    // 使用原始 fileId 作为 token，使 handle_upload 可以直接通过 fileId 匹配
    for (size_t i = 0; i < it->second.file_items.size(); ++i) {
        if (i > 0) response << ",";
        const std::string& fid = it->second.file_items[i].id.empty() ? std::to_string(i) : it->second.file_items[i].id;
        // token 值直接等于 fileId，方便 handle_upload 匹配
        response << "\"" << fid << "\":\"" << fid << "\"";
    }
    response << "}}";

    return http_response(200, response.str());
}

static std::string handle_upload(const std::string& path, const std::string& body, size_t content_length, int client_fd, const std::string& query_params) {
    std::string session_id = "";
    std::string file_id_str = "";
    
    if (path == "/api/localsend/v2/upload" || path == "/api/localsend/v1/send") {
        session_id = extract_query_param(query_params, "sessionId");
        file_id_str = extract_query_param(query_params, "fileId");
    } else {
        // 解析路径: /api/upload/{session_id}/{file_id}
        std::string prefix = "/api/upload/";
        if (path.length() > prefix.length()) {
            std::string upload_path = path.substr(prefix.length());
            size_t slash_pos = upload_path.find('/');
            if (slash_pos != std::string::npos) {
                session_id = upload_path.substr(0, slash_pos);
                file_id_str = upload_path.substr(slash_pos + 1);
            }
        }
    }
    
    if (session_id.empty() || file_id_str.empty()) {
        return http_response(400, "{\"error\":\"Invalid upload parameters\"}");
    }
    
    FileRequest* req = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        auto it = g_pending_requests.find(session_id);
        if (it == g_pending_requests.end()) {
            return http_response(404, "{\"error\":\"Session not found\"}");
        }
        
        if (!it->second.accepted) {
            return http_response(403, "{\"error\":\"Request not accepted\"}");
        }
        req = &it->second;
    }
    
    size_t file_index = 0;
    try {
        // file_id 可能是字符串 ID 也可能是索引
        // 尝试匹配 file_items 中的 ID
        bool found = false;
        for (size_t i = 0; i < req->file_items.size(); ++i) {
            if (req->file_items[i].id == file_id_str) {
                file_index = i;
                found = true;
                break;
            }
        }
        if (!found) {
            file_index = std::stoul(file_id_str);
        }
    } catch (...) {
        return http_response(400, "{\"error\":\"Invalid file id format\"}");
    }

    if (file_index >= req->file_items.size()) {
        return http_response(400, "{\"error\":\"Invalid file index\"}");
    }

    // 安全处理文件名并确保目录存在
    std::string safe_name = sanitize_filename(req->file_items[file_index].name);
    if (!ensure_directory(req->save_dir)) {
        LOGE("Failed to ensure directory: %{public}s", req->save_dir.c_str());
        return http_response(500, "{\"error\":\"Cannot access save directory\"}");
    }
    
    std::string save_path = get_unique_filename(req->save_dir, safe_name);
    
    // 设置超时防止挂起
    set_socket_timeouts(client_fd, 10);
    
    FILE* fp = fopen(save_path.c_str(), "wb");
    if (!fp) {
        LOGE("Failed to create file: %s", save_path.c_str());
        return http_response(500, "{\"error\":\"Cannot create file\"}");
    }
    
    // 如果 body 里已经有数据，先写入
    if (!body.empty()) {
        fwrite(body.c_str(), 1, body.size(), fp);
    }

    // 继续读取剩余数据
    size_t total_received = body.size();
    char buffer[BUFFER_SIZE];
    while (total_received < content_length) {
        // 检查取消
        if (req->is_cancelled) {
            fclose(fp);
            LOGW("Transfer %s cancelled by user", session_id.c_str());
            req->progress = 101;
            trigger_progress(session_id, 101);
            return http_response(500, "{\"error\":\"Transfer cancelled\"}");
        }

        ssize_t n = recv(client_fd, buffer, std::min((size_t)BUFFER_SIZE, content_length - total_received), 0);
        if (n <= 0) {
            if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                LOGW("Receive timeout for session: %s", session_id.c_str());
            }
            break;
        }
        fwrite(buffer, 1, n, fp);
        total_received += n;
        
        // 更新总体进度
        if (content_length > 0) {
            int32_t current_progress = (int32_t)(total_received * 100 / content_length);
            // 只在进度变化超过 1% 时触发，减少回调压力
            if (current_progress != (int32_t)req->progress) {
                req->progress = current_progress;
                trigger_progress(session_id, current_progress);
            }
        }
    }
    
    fclose(fp);
    
    if (total_received >= content_length) {
        req->progress = 100;
        trigger_progress(session_id, 100);
        return http_response(200, "{\"success\":true}");
    } else {
        req->progress = -1;
        trigger_progress(session_id, -1); // 触发失败进度回调
        return http_response(500, "{\"error\":\"Incomplete upload\"}");
    }
}

static std::string extract_query_param(const std::string& query, const std::string& key) {
    size_t pos = 0;
    while (pos < query.size()) {
        size_t end = query.find('&', pos);
        std::string pair = (end == std::string::npos) ? query.substr(pos) : query.substr(pos, end - pos);
        size_t eq = pair.find('=');
        if (eq != std::string::npos) {
            std::string k = pair.substr(0, eq);
            std::string v = pair.substr(eq + 1);
            if (k == key) {
                return v;
            }
        }
        if (end == std::string::npos) break;
        pos = end + 1;
    }
    return "";
}

static std::string handle_request(const std::string& method, const std::string& path, 
                                   const std::string& body, const std::string& sender_ip,
                                   size_t content_length, int client_fd, const std::string& query_params) {
    // CORS 预检请求
    if (method == "OPTIONS") {
        std::ostringstream response;
        response << "HTTP/1.1 200 OK\r\n";
        response << "Access-Control-Allow-Origin: *\r\n";
        response << "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
        response << "Access-Control-Allow-Headers: Content-Type\r\n";
        response << "Content-Length: 0\r\n";
        response << "\r\n";
        return response.str();
    }
    
    // 设备信息
    if ((path == "/info" || path == "/api/localsend/v2/info" || path == "/api/localsend/v1/info") && method == "GET") {
        return handle_info_request();
    }
    
    // 准备上传 (需要进行 PIN 校验与尝试次数限制)
    if ((path == "/api/prepare-upload" || path == "/api/localsend/v2/prepare-upload" || path == "/api/localsend/v1/send-request") && method == "POST") {
        if (!g_pin_code.empty()) {
            PinAttempt attempt_info;
            {
                std::lock_guard<std::mutex> lock(g_mutex);
                attempt_info = g_pin_attempts[sender_ip];
            }
            
            auto now = std::chrono::steady_clock::now();
            if (attempt_info.count >= 3) {
                auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - attempt_info.last_attempt_time).count();
                if (elapsed < 300) { // 5 分钟冷却期
                    LOGW("Sender %s blocked: too many PIN attempts, retry in %lld seconds", sender_ip.c_str(), static_cast<long long>(300 - elapsed));
                    return http_response(429, "{\"message\":\"Too many attempts.\"}");
                }
            }
            
            std::string req_pin = extract_query_param(query_params, "pin");
            if (req_pin != g_pin_code) {
                if (!req_pin.empty()) {
                    std::lock_guard<std::mutex> lock(g_mutex);
                    auto& real_info = g_pin_attempts[sender_ip];
                    auto inner_now = std::chrono::steady_clock::now();
                    if (real_info.count >= 3 && std::chrono::duration_cast<std::chrono::seconds>(inner_now - real_info.last_attempt_time).count() >= 300) {
                        real_info.count = 0;
                    }
                    real_info.count++;
                    real_info.last_attempt_time = inner_now;
                    
                    if (real_info.count >= 3) {
                        LOGW("Sender %s reached max PIN attempts, blocking", sender_ip.c_str());
                        return http_response(429, "{\"message\":\"Too many attempts.\"}");
                    }
                }
                LOGW("Unauthorized prepare-upload from %s: PIN mismatch (provided: '%s')", sender_ip.c_str(), req_pin.c_str());
                return http_response(401, "{\"message\":\"Invalid pin.\"}");
            }
            
            // 校验成功，重置该 IP 计数器
            {
                std::lock_guard<std::mutex> lock(g_mutex);
                g_pin_attempts[sender_ip] = PinAttempt{0, std::chrono::steady_clock::now()};
            }
        }
        return handle_prepare_upload(body, sender_ip);
    }
    
    // 文件上传
    if ((path.find("/api/upload/") == 0 || path == "/api/localsend/v2/upload" || path == "/api/localsend/v1/send") && method == "POST") {
        return handle_upload(path, body, content_length, client_fd, query_params);
    }
    
    // 注册设备
    if ((path == "/api/register" || path == "/api/localsend/v2/register" || path == "/api/localsend/v1/register") && method == "POST") {
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            std::string device_json = body;
            size_t brace_pos = device_json.find('{');
            if (brace_pos != std::string::npos) {
                device_json.insert(brace_pos + 1, "\"address\":\"" + sender_ip + "\",\"ip\":\"" + sender_ip + "\",");
            }
            g_discovered_devices[sender_ip] = device_json;
            g_device_timestamps[sender_ip] = std::chrono::steady_clock::now();
        }
        trigger_device_callback();
        std::string response_body;
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            response_body = build_device_info_json(false);
        }
        return http_response(200, response_body);
    }

    // 取消传输
    if ((path == "/api/cancel" || path == "/api/localsend/v2/cancel" || path == "/api/localsend/v1/cancel") && method == "POST") {
        std::string session_id = extract_query_param(query_params, "sessionId");
        if (!session_id.empty()) {
            std::lock_guard<std::mutex> lock(g_mutex);
            auto it = g_pending_requests.find(session_id);
            if (it != g_pending_requests.end()) {
                it->second.is_cancelled = true;
                LOGI("Session %s cancelled by remote peer", session_id.c_str());
                it->second.progress = -1;
                trigger_progress(session_id, -1);
                return http_response(200, "{\"success\":true}");
            }
        }
        return http_response(400, "{\"error\":\"Invalid session ID\"}");
    }
    
    return http_response(404, "{\"error\":\"Not found\"}");
}

static void handle_client_connection(int client, struct sockaddr_in client_addr) {
    // 获取客户端 IP
    char client_ip[INET_ADDRSTRLEN] = {0};
    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
    std::string sender_ip(client_ip);
    
    // 设置超时防止挂起
    set_socket_timeouts(client, 15);
    
    // 读取请求
    char buffer[BUFFER_SIZE];
    ssize_t len = recv(client, buffer, BUFFER_SIZE - 1, 0);
    if (len <= 0) {
        close(client);
        return;
    }
    buffer[len] = '\0';
    
    // 解析请求
    std::string request_str(buffer, len);
    size_t method_end = request_str.find(' ');
    size_t path_end = request_str.find(' ', method_end + 1);
    size_t body_start = request_str.find("\r\n\r\n");
    
    // 解析 Content-Length
    size_t content_length = 0;
    size_t cl_pos = request_str.find("Content-Length:");
    if (cl_pos == std::string::npos) {
        cl_pos = request_str.find("content-length:");
    }
    if (cl_pos != std::string::npos) {
        size_t cl_end = request_str.find("\r\n", cl_pos);
        if (cl_end != std::string::npos) {
            std::string cl_str = request_str.substr(cl_pos + 15, cl_end - cl_pos - 15);
            // 去除空格
            cl_str.erase(0, cl_str.find_first_not_of(" \t"));
            try {
                content_length = std::stoul(cl_str);
            } catch (...) {
                content_length = 0;
            }
        }
    }
    
    if (method_end != std::string::npos && path_end != std::string::npos) {
        std::string method = request_str.substr(0, method_end);
        std::string path = request_str.substr(method_end + 1, path_end - method_end - 1);
        std::string query_params = "";
        size_t q_pos = path.find('?');
        if (q_pos != std::string::npos) {
            query_params = path.substr(q_pos + 1);
            path = path.substr(0, q_pos);
        }
        std::string body = (body_start != std::string::npos) ? request_str.substr(body_start + 4) : "";
        
        // 循环读取未完结的 HTTP Body 分包，确保解析完整
        bool is_upload = (method == "POST" && (path.find("/api/upload/") == 0 || 
                                               path == "/api/localsend/v2/upload" || 
                                               path == "/api/localsend/v1/send"));
        if (!is_upload && content_length > 0 && body.size() < content_length) {
            size_t remaining = content_length - body.size();
            std::vector<char> temp_buf(BUFFER_SIZE);
            while (remaining > 0) {
                ssize_t read_len = recv(client, temp_buf.data(), std::min(remaining, (size_t)BUFFER_SIZE), 0);
                if (read_len <= 0) break;
                body.append(temp_buf.data(), read_len);
                remaining -= read_len;
            }
        }
        
        std::string response = handle_request(method, path, body, sender_ip, content_length, client, query_params);
        send(client, response.c_str(), response.size(), 0);
    }
    
    close(client);
}

static void http_loop() {
    // 创建 HTTP 服务器 socket
    g_http_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (g_http_socket < 0) return;
    
    int reuse = 1;
    setsockopt(g_http_socket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(g_server_port);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(g_http_socket, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(g_http_socket);
        g_http_socket = -1;
        return;
    }
    
    listen(g_http_socket, 10); // 增加 backlog 到 10
    
    while (g_server_running) {
        struct pollfd pfd;
        pfd.fd = g_http_socket;
        pfd.events = POLLIN;
        
        int ret = poll(&pfd, 1, 1000);
        if (ret <= 0) continue;
        
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int client = accept(g_http_socket, (struct sockaddr*)&client_addr, &client_len);
        if (client < 0) continue;
        
        // 每一个客户端连接都由独立线程来处理，避免阻塞主循环
        std::thread(handle_client_connection, client, client_addr).detach();
    }
}

// ============================================================================
// FFI 实现
// ============================================================================

extern "C" {

void localsend_rust_free_string(char* s) {
    if (s) {
        free(s);
    }
}

static void task_manager_thread() {
    LOGI("Task manager thread started");
    while (g_server_running) {
        std::this_thread::sleep_for(std::chrono::minutes(1));
        
        std::lock_guard<std::mutex> lock(g_mutex);
        auto now = std::chrono::steady_clock::now();
        
        for (auto it = g_pending_requests.begin(); it != g_pending_requests.end(); ) {
            // 清理超过 30 分钟的旧任务
            auto age = std::chrono::duration_cast<std::chrono::minutes>(now - it->second.creation_time).count();
            if (age > 30) {
                LOGI("Cleaning up stale task: %s (age: %lld mins)", it->first.c_str(), (long long)age);
                it = g_pending_requests.erase(it);
            } else {
                ++it;
            }
        }
    }
    LOGI("Task manager thread stopped");
}

bool localsend_start_server(const char* alias, uint16_t port, const char* local_ip) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_server_running) {
        return true;
    }
    
    if (alias && alias[0] != '\0') {
        g_device_alias = alias;
    }
    g_server_port = port;
    
    if (g_device_fingerprint.empty()) {
        g_device_fingerprint = generate_fingerprint();
    }
    
    if (local_ip && local_ip[0] != '\0') {
        g_local_ip = local_ip;
    } else {
        g_local_ip = get_local_ip();
    }
    
    // 启动多播发现
    if (setup_multicast_socket()) {
        g_discovery_running = true;
        g_discovery_thread = std::thread(discovery_loop);
        g_discovery_thread.detach();
    }
    
    // 启动 HTTP 服务器
    g_server_running = true;
    g_http_thread = std::thread(http_loop);
    g_http_thread.detach();
    
    // 启动管理线程
    std::thread(task_manager_thread).detach();
    
    LOGI("LocalSend server started on port %d with alias %s", g_server_port, g_device_alias.c_str());
    return true;
}

void localsend_stop_server(void) {
    g_server_running = false;
    g_discovery_running = false;
    
    if (g_http_socket >= 0) {
        close(g_http_socket);
        g_http_socket = -1;
    }
    
    if (g_multicast_socket >= 0) {
        close(g_multicast_socket);
        g_multicast_socket = -1;
    }
    
    if (g_http_thread.joinable()) {
        g_http_thread.join();
    }
    
    if (g_discovery_thread.joinable()) {
        g_discovery_thread.join();
    }
    
    // 清除缓存的已发现设备列表并触发 UI 刷新回调
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_discovered_devices.clear();
        g_device_timestamps.clear();
    }
    trigger_device_callback();
}

bool localsend_is_server_running(void) {
    return g_server_running;
}

char* localsend_scan_devices(void) {
    // 发送公告
    send_announcement();
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    std::ostringstream json;
    json << "[";
    
    bool first = true;
    for (auto it = g_discovered_devices.begin(); it != g_discovered_devices.end(); ++it) {
        if (!first) json << ",";
        json << it->second;
        first = false;
    }
    
    json << "]";
    return alloc_string(json.str());
}

char* localsend_get_network_info(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    std::ostringstream json;
    json << "{";
    json << "\"ip\":\"" << g_local_ip << "\",";
    json << "\"port\":" << g_server_port << ",";
    json << "\"multicastGroup\":\"" << MULTICAST_GROUP << "\",";
    json << "\"version\":\"2.0\",";
    json << "\"alias\":\"" << json_escape(g_device_alias) << "\",";
    json << "\"fingerprint\":\"" << g_device_fingerprint << "\"";
    json << "}";
    
    return alloc_string(json.str());
}

static void send_file_thread(std::string target_ip, uint16_t port, std::string session_id) {
    FileRequest* req = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        auto it = g_pending_requests.find(session_id);
        if (it == g_pending_requests.end()) return;
        req = &it->second;
    }

    int64_t total_sent_all = 0;
    for (size_t i = 0; i < req->file_items.size(); ++i) {
        // 检查取消
        if (req->is_cancelled) break;

        std::string file_path = req->file_paths[i];
        std::string file_name = req->file_items[i].name;
        std::string file_id = req->file_items[i].id.empty() ? std::to_string(i) : req->file_items[i].id;
        
        int file_fd = (i < req->file_fds.size()) ? req->file_fds[i] : -1;
        FILE* fp = nullptr;
        if (file_fd >= 0) {
            fp = fdopen(file_fd, "rb");
            if (fp) {
                // 已成功关联 FILE*，设置 file_fds[i] = -1 以免析构时重复关闭
                req->file_fds[i] = -1;
            } else {
                LOGE("Failed to fdopen fd %{public}d, error: %{public}d", file_fd, errno);
                close(file_fd);
                req->file_fds[i] = -1;
            }
        }
        
        if (!fp) {
            fp = fopen(file_path.c_str(), "rb");
        }
        
        if (!fp) continue;
        
        size_t file_size = req->file_items[i].size;
        if (file_size == 0) {
            fseek(fp, 0, SEEK_END);
            file_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
        }
        
        // 创建连接
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            LOGE("Failed to create socket for upload to %{public}s", target_ip.c_str());
            fclose(fp);
            continue;
        }
        
        // 设置超时防止挂起
        set_socket_timeouts(sock, 10);
        
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, target_ip.c_str(), &addr.sin_addr);
        
        if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            LOGE("Failed to connect to %{public}s:%{public}d for upload", target_ip.c_str(), port);
            fclose(fp);
            close(sock);
            continue;
        }
        
        // 发送 POST 请求头
        std::ostringstream header;
        header << "POST /api/upload/" << session_id << "/" << file_id << " HTTP/1.1\r\n";
        header << "Host: " << target_ip << ":" << port << "\r\n";
        header << "Content-Type: application/octet-stream\r\n";
        header << "Content-Length: " << file_size << "\r\n";
        header << "Connection: close\r\n";
        header << "\r\n";
        
        std::string header_str = header.str();
        send(sock, header_str.c_str(), header_str.size(), 0);
        
        // 发送文件内容
        char buffer[BUFFER_SIZE];
        size_t file_sent = 0;
        while (file_sent < file_size) {
            // 检查取消
            if (req->is_cancelled) {
                LOGW("Upload %{public}s cancelled by user", session_id.c_str());
                break;
            }

            size_t n = fread(buffer, 1, BUFFER_SIZE, fp);
            if (n <= 0) break;
            
            ssize_t s = send(sock, buffer, n, 0);
            if (s <= 0) {
                LOGE("Send failed for session %{public}s, error: %{public}d", session_id.c_str(), errno);
                break;
            }
            
            file_sent += s;
            total_sent_all += s;
            
            // 更新进度
            if (req->total_size > 0) {
                int32_t current_progress = (int32_t)(total_sent_all * 100 / req->total_size);
                if (current_progress != (int32_t)req->progress && current_progress < 100) {
                    req->progress = current_progress;
                    trigger_progress(session_id, current_progress);
                }
            }
        }
        
        fclose(fp);
        close(sock);
        if (req->is_cancelled) break;
    }
    
    if (req->is_cancelled) {
        LOGI("Finalizing cancelled session: %{public}s", session_id.c_str());
        req->progress = 101;
        trigger_progress(session_id, 101); // 101 表示取消
    } else if (total_sent_all >= req->total_size) {
        LOGI("Upload session completed successfully: %{public}s", session_id.c_str());
        req->progress = 100;
        trigger_progress(session_id, 100);
    } else {
        LOGE("Upload session failed: %{public}s", session_id.c_str());
        req->progress = -1;
        trigger_progress(session_id, -1); // 触发失败进度回调
    }
}

bool localsend_send_request(const char* target_ip, uint16_t port, const char* files_json) {
    if (!target_ip || !files_json) return false;

    // 解析 files_json 数组 (ArkTS FileInfo[] JSON 格式)
    // 结构: [{"id":"...","fileName":"...","size":123,"filePath":"/cache/..."}]
    std::string files_str(files_json);
    std::vector<std::string> filenames;
    std::vector<std::string> filepaths;
    std::vector<std::string> fileids;
    std::vector<int64_t> file_sizes;
    int64_t total_size = 0;

    // 使用括号深度匹配，正确处理嵌套结构
    size_t pos = 0;
    while (pos < files_str.size()) {
        size_t obj_start = files_str.find('{', pos);
        if (obj_start == std::string::npos) break;

        // 找到匹配的 }
        int depth = 0;
        size_t obj_end = std::string::npos;
        for (size_t i = obj_start; i < files_str.size(); ++i) {
            if (files_str[i] == '{') depth++;
            else if (files_str[i] == '}') {
                depth--;
                if (depth == 0) { obj_end = i; break; }
            }
        }
        if (obj_end == std::string::npos) break;

        std::string obj = files_str.substr(obj_start, obj_end - obj_start + 1);

        // 解析 id
        std::string file_id = json_extract_string(obj, "id");
        if (file_id.empty()) file_id = std::to_string(fileids.size());
        fileids.push_back(file_id);

        // 解析 fileName
        std::string filename = json_extract_string(obj, "fileName");
        filenames.push_back(filename);

        // 解析 filePath（cacheDir 下的真实路径）
        std::string filepath = json_extract_string(obj, "filePath");
        filepaths.push_back(filepath);

        // 解析 size
        int64_t size_val = json_extract_number(obj, "size");
        file_sizes.push_back(size_val);
        total_size += size_val;

        pos = obj_end + 1;
    }

    if (fileids.empty()) {
        LOGE("No files parsed from JSON: %s", files_json);
        return false;
    }

    // 创建 socket 连接
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        LOGE("localsend_send_request: Failed to create socket, errno = %d", errno);
        return false;
    }

    set_socket_timeouts(sock, 10);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, target_ip, &addr.sin_addr);

    LOGI("localsend_send_request: Connecting to %{public}s:%{public}d", target_ip, port);
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        LOGE("localsend_send_request: Connection to %{public}s:%{public}d failed, errno = %{public}d", target_ip, port, errno);
        close(sock);
        return false;
    }
    LOGI("localsend_send_request: Connected to %{public}s:%{public}d", target_ip, port);

    // 构造 LocalSend v2 格式的 prepare-upload body
    // {"info":{"alias":"...","version":"2.0","deviceModel":"HarmonyOS","deviceType":"mobile","fingerprint":"...","port":53317,"protocol":"http","download":false},"files":{"fileId":{"id":"...","fileName":"...","size":123,"fileType":"application/octet-stream","preview":null}}}
    std::ostringstream body;
    body << "{";
    body << "\"info\":{";
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        body << "\"alias\":\"" << json_escape(g_device_alias) << "\",";
        body << "\"version\":\"2.0\",";
        body << "\"deviceModel\":\"HarmonyOS\",";
        body << "\"deviceType\":\"mobile\",";
        body << "\"fingerprint\":\"" << g_device_fingerprint << "\",";
        body << "\"port\":" << g_server_port << ",";
    }
    body << "\"protocol\":\"http\",";
    body << "\"download\":false";
    body << "},";
    body << "\"files\":{";
    for (size_t i = 0; i < fileids.size(); ++i) {
        if (i > 0) body << ",";
        body << "\"" << fileids[i] << "\":{";
        body << "\"id\":\"" << fileids[i] << "\",";
        body << "\"fileName\":\"" << json_escape(filenames[i]) << "\",";
        body << "\"size\":" << file_sizes[i] << ",";
        // 简单根据扩展名推断 MIME
        std::string ext;
        size_t dot = filenames[i].rfind('.');
        if (dot != std::string::npos) ext = filenames[i].substr(dot + 1);
        std::string mime = "application/octet-stream";
        if (ext == "jpg" || ext == "jpeg") mime = "image/jpeg";
        else if (ext == "png") mime = "image/png";
        else if (ext == "gif") mime = "image/gif";
        else if (ext == "mp4") mime = "video/mp4";
        else if (ext == "mp3") mime = "audio/mpeg";
        else if (ext == "txt") mime = "text/plain";
        else if (ext == "pdf") mime = "application/pdf";
        body << "\"fileType\":\"" << mime << "\"";
        body << "}";
    }
    body << "}}";

    std::string body_str = body.str();

    // 发送 prepare-upload 请求
    std::ostringstream request;
    request << "POST /api/localsend/v2/prepare-upload HTTP/1.1\r\n";
    request << "Host: " << target_ip << ":" << port << "\r\n";
    request << "Content-Type: application/json\r\n";
    request << "Content-Length: " << body_str.size() << "\r\n";
    request << "Connection: close\r\n";
    request << "\r\n";
    request << body_str;

    std::string req_str = request.str();
    LOGI("localsend_send_request: Sending prepare-upload request to %{public}s:%{public}d, content:\n%{public}s", target_ip, port, req_str.c_str());
    send(sock, req_str.c_str(), req_str.size(), 0);

    // 读取响应
    char buffer[8192];
    ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
    close(sock);

    if (len > 0) {
        buffer[len] = '\0';
        std::string response(buffer);
        LOGI("localsend_send_request: Received response from %{public}s:%{public}d, size = %{public}zd, content:\n%{public}s", target_ip, port, len, response.c_str());
        if (response.find("200 OK") != std::string::npos) {
            // 解析 sessionId
            std::string session_id = json_extract_string(response, "sessionId");
            if (session_id.empty()) {
                session_id = json_extract_string(response, "id");
            }

            if (!session_id.empty()) {
                LOGI("localsend_send_request: Handshake success, session = %{public}s", session_id.c_str());
                // 创建任务记录
                FileRequest fr;
                fr.id = session_id;
                fr.sender_ip = target_ip;
                for (size_t i = 0; i < filenames.size(); ++i) {
                    FileItem item;
                    item.id = fileids[i];
                    item.name = filenames[i];
                    item.size = (i < file_sizes.size()) ? file_sizes[i] : 0;
                    fr.file_items.push_back(std::move(item));
                }
                fr.file_paths = filepaths;
                fr.total_size = total_size;
                fr.progress = 0;
                fr.accepted = true;
                fr.is_sending = true;

                {
                    std::lock_guard<std::mutex> lock(g_mutex);
                    g_pending_requests[session_id] = std::move(fr);
                }

                // 启动发送线程
                std::thread(send_file_thread, std::string(target_ip), port, session_id).detach();
                return true;
            } else {
                LOGE("localsend_send_request: Failed to parse sessionId/id from response: %{public}s", response.c_str());
            }
        } else {
            LOGW("localsend_send_request: prepare-upload rejected, response: %{public}s", response.c_str());
        }
    } else {
        LOGE("localsend_send_request: Failed to receive response from %{public}s:%{public}d, len = %{public}zd, errno = %{public}d. Request content was:\n%{public}s", 
             target_ip, port, len, errno, req_str.c_str());
    }

    return false;
}

bool localsend_send_announcement(void) {
    send_announcement();
    return true;
}

int32_t localsend_get_device_count(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return static_cast<int32_t>(g_discovered_devices.size());
}

char* localsend_get_registered_devices(void) {
    return localsend_scan_devices();
}

char* localsend_get_pending_requests(void) {
    // TODO: 实现待处理请求列表
    return alloc_string("[]");
}

char* localsend_get_fingerprint(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_device_fingerprint.empty()) {
        g_device_fingerprint = generate_fingerprint();
    }
    
    return alloc_string(g_device_fingerprint);
}

bool localsend_set_alias(const char* alias) {
    if (!alias || alias[0] == '\0') return false;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    g_device_alias = alias;
    return true;
}

void localsend_set_pin_code(const char* pin) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (pin) {
        g_pin_code = pin;
    } else {
        g_pin_code = "";
    }
    g_pin_attempts.clear();
    LOGI("LocalSend PIN code updated. Length: %zu", g_pin_code.length());
}

char* localsend_rust_hello(void) {
    return alloc_string("Hello from LocalSend Native (C++)!");
}

bool localsend_accept_request(const char* request_id, const char* save_dir) {
    if (!request_id) return false;
    
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        
        auto it = g_pending_requests.find(request_id);
        if (it == g_pending_requests.end()) return false;
        
        it->second.accepted = true;
        if (save_dir) {
            it->second.save_dir = save_dir;
        }
    }
    
    // 唤醒挂起在 prepare-upload 的线程
    g_cv.notify_all();
    return true;
}

bool localsend_reject_request(const char* request_id) {
    if (!request_id) return false;
    
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        
        auto it = g_pending_requests.find(request_id);
        if (it == g_pending_requests.end()) return false;
        
        it->second.is_cancelled = true;
    }
    
    // 唤醒挂起在 prepare-upload 的线程
    g_cv.notify_all();
    return true;
}

int32_t localsend_get_receive_progress(const char* request_id) {
    if (!request_id) return -1;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    auto it = g_pending_requests.find(request_id);
    if (it == g_pending_requests.end()) return -1;
    
    return it->second.progress;
}

bool localsend_cancel_transfer(const char* request_id) {
    if (!request_id) return false;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    auto it = g_pending_requests.find(request_id);
    if (it == g_pending_requests.end()) return false;
    
    // 设置取消标志
    it->second.is_cancelled = true;
    
    // 我们保留记录以便 UI 能够显示“已取消”，或者稍后手动清理
    return true;
}

void localsend_set_device_callback(LocalsendDeviceCallback callback) {
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_device_callback = callback;
    }
    trigger_device_callback();
}

void localsend_set_file_callback(LocalsendFileCallback callback) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_file_callback = callback;
}

void localsend_set_progress_callback(LocalsendProgressCallback callback) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_progress_callback = callback;
}

} // extern "C"

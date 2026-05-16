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
    constexpr const char* MULTICAST_GROUP = "239.255.255.250";
    constexpr uint16_t MULTICAST_PORT = 53317;
    constexpr uint16_t HTTP_PORT = 53317;
    constexpr size_t BUFFER_SIZE = 65536;
    constexpr int DISCOVERY_TIMEOUT_MS = 3000;
}

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
    std::string save_dir;
    int64_t total_size;
    std::atomic<int32_t> progress;
    std::atomic<bool> is_cancelled;
    bool accepted;
    bool is_sending; // true: 发送, false: 接收
    std::chrono::steady_clock::time_point creation_time;

    FileRequest() : progress(0), is_cancelled(false), accepted(false), is_sending(false), 
                    creation_time(std::chrono::steady_clock::now()) {}
    
    // 移动构造函数
    FileRequest(FileRequest&& other) noexcept :
        id(std::move(other.id)),
        sender_ip(std::move(other.sender_ip)),
        sender_alias(std::move(other.sender_alias)),
        file_items(std::move(other.file_items)),
        file_paths(std::move(other.file_paths)),
        save_dir(std::move(other.save_dir)),
        total_size(other.total_size),
        progress(other.progress.load()),
        is_cancelled(other.is_cancelled.load()),
        accepted(other.accepted),
        is_sending(other.is_sending),
        creation_time(other.creation_time) {}

    // 移动赋值运算符
    FileRequest& operator=(FileRequest&& other) noexcept {
        if (this != &other) {
            id = std::move(other.id);
            sender_ip = std::move(other.sender_ip);
            sender_alias = std::move(other.sender_alias);
            file_items = std::move(other.file_items);
            file_paths = std::move(other.file_paths);
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
static std::atomic<bool> g_server_running{false};
static std::atomic<bool> g_discovery_running{false};
static std::string g_device_alias = "HarmonyOS Device";
static uint16_t g_server_port = HTTP_PORT;
static std::string g_device_fingerprint;
static std::string g_local_ip;
static std::map<std::string, std::string> g_discovered_devices;
static std::map<std::string, FileRequest> g_pending_requests;
static std::thread g_discovery_thread;
static std::thread g_http_thread;
static int g_multicast_socket = -1;
static int g_http_socket = -1;
static LocalsendDeviceCallback g_device_callback = nullptr;
static LocalsendFileCallback g_file_callback = nullptr;
static LocalsendProgressCallback g_progress_callback = nullptr;

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
    struct stat st = {0};
    if (stat(path.c_str(), &st) == -1) {
        return mkdir(path.c_str(), 0777) == 0;
    }
    return S_ISDIR(st.st_mode);
}

static std::string get_all_ips() {
    struct ifaddrs *ifAddrStruct = NULL;
    struct ifaddrs *ifa = NULL;
    std::string ips;

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
            if (!ips.empty()) ips += ",";
            ips += addressBuffer;
        }
    }
    if (ifAddrStruct != NULL) freeifaddrs(ifAddrStruct);
    return ips.empty() ? "127.0.0.1" : ips;
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
    
    // 加入多播组
    struct ip_mreq mreq;
    memset(&mreq, 0, sizeof(mreq));
    inet_pton(AF_INET, MULTICAST_GROUP, &mreq.imr_multiaddr);
    mreq.imr_interface.s_addr = INADDR_ANY;
    
    if (setsockopt(g_multicast_socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq)) < 0) {
        close(g_multicast_socket);
        g_multicast_socket = -1;
        return false;
    }
    
    return true;
}

static void send_announcement() {
    if (g_multicast_socket < 0) return;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    // 构建公告消息
    std::ostringstream json;
    json << "{";
    json << "\"alias\":\"" << json_escape(g_device_alias) << "\",";
    json << "\"fingerprint\":\"" << g_device_fingerprint << "\",";
    json << "\"port\":" << g_server_port << ",";
    json << "\"version\":\"2.0\",";
    json << "\"deviceModel\":\"HarmonyOS\",";
    json << "\"deviceType\":\"mobile\",";
    json << "\"download\":true,";
    json << "\"announce\":true";
    json << "}";
    
    std::string message = json.str();
    
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
        if (ret <= 0) continue;
        
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
        std::lock_guard<std::mutex> lock(g_mutex);
        g_discovered_devices[sender_ip] = std::string(buffer);
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
    
    std::ostringstream json;
    json << "{";
    json << "\"alias\":\"" << json_escape(g_device_alias) << "\",";
    json << "\"fingerprint\":\"" << g_device_fingerprint << "\",";
    json << "\"port\":" << g_server_port << ",";
    json << "\"version\":\"2.0\",";
    json << "\"deviceModel\":\"HarmonyOS\",";
    json << "\"deviceType\":\"mobile\",";
    json << "\"download\":true,";
    json << "\"announce\":true";
    json << "}";
    
    return http_response(200, json.str());
}

// ============================================================================
// 文件传输处理
// ============================================================================

// 简单的 JSON 解析辅助函数
static std::string json_extract_string(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\":\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    
    pos += search.length();
    size_t end = json.find("\"", pos);
    if (end == std::string::npos) return "";
    
    return json.substr(pos, end - pos);
}

static int64_t json_extract_number(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\":";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return 0;
    
    pos += search.length();
    return std::stoll(json.substr(pos));
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
    // 解析请求
    std::string sender_alias = json_extract_string(body, "sender_alias");
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

    // 解析文件列表
    size_t files_pos = body.find("\"files\":");
    if (files_pos != std::string::npos) {
        size_t array_start = body.find("[", files_pos);
        size_t array_end = body.find("]", array_start);
        if (array_start != std::string::npos && array_end != std::string::npos) {
            std::string files_array = body.substr(array_start, array_end - array_start + 1);
            
            // 查找每一个对象 { ... }
            size_t obj_pos = 0;
            while ((obj_pos = files_array.find("{", obj_pos)) != std::string::npos) {
                size_t obj_end = files_array.find("}", obj_pos);
                if (obj_end == std::string::npos) break;
                
                std::string obj_str = files_array.substr(obj_pos, obj_end - obj_pos + 1);
                
                FileItem item;
                item.id = json_extract_string(obj_str, "id");
                item.name = json_extract_string(obj_str, "fileName");
                if (item.name.empty()) item.name = json_extract_string(obj_str, "name");
                item.type = json_extract_string(obj_str, "fileType");
                item.preview = json_extract_string(obj_str, "preview");
                
                // 提取 size
                size_t size_pos = obj_str.find("\"size\":");
                if (size_pos != std::string::npos) {
                    size_pos += 7;
                    size_t size_end = obj_str.find_first_of(",}", size_pos);
                    if (size_end != std::string::npos) {
                        item.size = std::stoll(obj_str.substr(size_pos, size_end - size_pos));
                    } else {
                        item.size = 0;
                    }
                } else {
                    item.size = 0;
                }
                
                fr.total_size += item.size;
                fr.file_items.push_back(std::move(item));
                
                obj_pos = obj_end + 1;
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

    // 返回响应
    std::ostringstream response;
    response << "{";
    response << "\"sessionId\":\"" << request_id << "\",";
    response << "\"files\":{";
    
    // 为每个文件生成 token
    for (size_t i = 0; i < fr.file_items.size(); ++i) {
        if (i > 0) response << ",";
        response << "\"" << (fr.file_items[i].id.empty() ? std::to_string(i) : fr.file_items[i].id) 
                 << "\":\"" << request_id << "_" << i << "\"";
    }
    response << "}}";

    // 存储请求 (MOVE MUST BE LAST)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_pending_requests[request_id] = std::move(fr);
    }
    
    return http_response(200, response.str());
}

static std::string handle_upload(const std::string& path, const std::string& body, size_t content_length, int client_fd) {
    // 解析路径: /api/upload/{session_id}/{file_id}
    std::string prefix = "/api/upload/";
    if (path.length() <= prefix.length()) {
        return http_response(400, "{\"error\":\"Invalid upload path\"}");
    }
    
    std::string upload_path = path.substr(prefix.length());
    size_t slash_pos = upload_path.find('/');
    if (slash_pos == std::string::npos) {
        return http_response(400, "{\"error\":\"Invalid upload path\"}");
    }
    
    std::string session_id = upload_path.substr(0, slash_pos);
    std::string file_id_str = upload_path.substr(slash_pos + 1);
    
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
        LOGE("Failed to ensure directory: %s", req->save_dir.c_str());
        return http_response(500, "{\"error\":\"Cannot access save directory\"}");
    }
    
    std::string save_path = req->save_dir + "/" + safe_name;
    
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
        return http_response(500, "{\"error\":\"Incomplete upload\"}");
    }
}

static std::string handle_request(const std::string& method, const std::string& path, 
                                   const std::string& body, const std::string& sender_ip,
                                   size_t content_length, int client_fd) {
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
    if (path == "/info" && method == "GET") {
        return handle_info_request();
    }
    
    // 准备上传
    if (path == "/api/prepare-upload" && method == "POST") {
        return handle_prepare_upload(body, sender_ip);
    }
    
    // 文件上传
    if (path.find("/api/upload/") == 0 && method == "POST") {
        return handle_upload(path, body, content_length, client_fd);
    }
    
    // 注册设备
    if (path == "/api/register" && method == "POST") {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_discovered_devices[sender_ip] = body;
        return http_response(200, "{\"success\":true}");
    }
    
    return http_response(404, "{\"error\":\"Not found\"}");
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
    
    listen(g_http_socket, 5);
    
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
        
        // 获取客户端 IP
        char client_ip[INET_ADDRSTRLEN] = {0};
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
        std::string sender_ip(client_ip);
        
        // 读取请求
        char buffer[BUFFER_SIZE];
        ssize_t len = recv(client, buffer, BUFFER_SIZE - 1, 0);
        if (len <= 0) {
            close(client);
            continue;
        }
        buffer[len] = '\0';
        
        // 解析请求
        std::string request_str(buffer);
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
            std::string body = (body_start != std::string::npos) ? request_str.substr(body_start + 4) : "";
            
            std::string response = handle_request(method, path, body, sender_ip, content_length, client);
            send(client, response.c_str(), response.size(), 0);
        }
        
        close(client);
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

bool localsend_start_server(const char* alias, uint16_t port) {
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
    
    g_local_ip = get_local_ip();
    
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
}

bool localsend_is_server_running(void) {
    return g_server_running;
}

char* localsend_scan_devices(void) {
    // 发送公告
    send_announcement();
    
    // 等待响应
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
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
        
        FILE* fp = fopen(file_path.c_str(), "rb");
        if (!fp) continue;
        
        fseek(fp, 0, SEEK_END);
        size_t file_size = ftell(fp);
        fseek(fp, 0, SEEK_SET);
        
        // 创建连接
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            LOGE("Failed to create socket for upload to %s", target_ip.c_str());
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
            LOGE("Failed to connect to %s:%d for upload", target_ip.c_str(), port);
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
                LOGW("Upload %s cancelled by user", session_id.c_str());
                break;
            }

            size_t n = fread(buffer, 1, BUFFER_SIZE, fp);
            if (n <= 0) break;
            
            ssize_t s = send(sock, buffer, n, 0);
            if (s <= 0) {
                LOGE("Send failed for session %s, error: %d", session_id.c_str(), errno);
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
        LOGI("Finalizing cancelled session: %s", session_id.c_str());
        trigger_progress(session_id, 101); // 101 表示取消
    } else if (total_sent_all >= req->total_size) {
        LOGI("Upload session completed successfully: %s", session_id.c_str());
        req->progress = 100;
        trigger_progress(session_id, 100);
    }
}

bool localsend_send_request(const char* target_ip, uint16_t port, const char* files_json) {
    if (!target_ip || !files_json) return false;
    
    // 解析 files_json 获取文件信息
    std::string files_str(files_json);
    std::vector<std::string> filenames;
    std::vector<std::string> filepaths;
    int64_t total_size = 0;
    
    size_t pos = 0;
    while ((pos = files_str.find("\"fileName\":\"", pos)) != std::string::npos) {
        pos += 12;
        size_t end = files_str.find("\"", pos);
        if (end != std::string::npos) {
            filenames.push_back(files_str.substr(pos, end - pos));
        }
    }
    
    pos = 0;
    while ((pos = files_str.find("\"filePath\":\"", pos)) != std::string::npos) {
        pos += 12;
        size_t end = files_str.find("\"", pos);
        if (end != std::string::npos) {
            filepaths.push_back(files_str.substr(pos, end - pos));
        }
    }
    
    pos = 0;
    while ((pos = files_str.find("\"size\":", pos)) != std::string::npos) {
        pos += 7;
        size_t end = files_str.find_first_of(",}", pos);
        if (end != std::string::npos) {
            total_size += std::stoll(files_str.substr(pos, end - pos));
        }
    }

    // 创建 socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return false;
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, target_ip, &addr.sin_addr);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return false;
    }
    
    // 发送准备上传请求
    std::ostringstream request;
    request << "POST /api/prepare-upload HTTP/1.1\r\n";
    request << "Host: " << target_ip << ":" << port << "\r\n";
    request << "Content-Type: application/json\r\n";
    request << "Content-Length: " << strlen(files_json) << "\r\n";
    request << "Connection: close\r\n";
    request << "\r\n";
    request << files_json;
    
    std::string req_str = request.str();
    send(sock, req_str.c_str(), req_str.size(), 0);
    
    // 读取响应
    char buffer[4096];
    ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
    close(sock);
    
    if (len > 0) {
        buffer[len] = '\0';
        std::string response(buffer);
        if (response.find("200 OK") != std::string::npos) {
            // 解析 sessionId
            std::string session_id = json_extract_string(response, "sessionId");
            if (session_id.empty()) {
                // 有些版本可能是 sessionId
                session_id = json_extract_string(response, "id");
            }
            
            if (!session_id.empty()) {
                // 创建任务记录
                FileRequest fr;
                fr.id = session_id;
                fr.sender_ip = target_ip;
                for (size_t i = 0; i < filenames.size(); ++i) {
                    FileItem item;
                    item.name = filenames[i];
                    item.size = 0; // 之前没存，暂时填0或从 total_size 估算
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
            }
        }
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

char* localsend_rust_hello(void) {
    return alloc_string("Hello from LocalSend Native (C++)!");
}

bool localsend_accept_request(const char* request_id, const char* save_dir) {
    if (!request_id) return false;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    auto it = g_pending_requests.find(request_id);
    if (it == g_pending_requests.end()) return false;
    
    it->second.accepted = true;
    if (save_dir) {
        it->second.save_dir = save_dir;
    }
    
    // TODO: 启动文件接收线程
    
    return true;
}

bool localsend_reject_request(const char* request_id) {
    if (!request_id) return false;
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    auto it = g_pending_requests.find(request_id);
    if (it == g_pending_requests.end()) return false;
    
    g_pending_requests.erase(it);
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
    std::lock_guard<std::mutex> lock(g_mutex);
    g_device_callback = callback;
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

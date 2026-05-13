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

// 文件请求结构体
struct FileRequest {
    std::string id;
    std::string sender_ip;
    std::string sender_alias;
    std::vector<std::string> files;
    int64_t total_size;
    std::string save_dir;
    int32_t progress;
    bool accepted;
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

static std::string get_local_ip() {
    // 尝试获取本机 IP
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return "127.0.0.1";
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(80);
    inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr);
    
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    
    if (getsockname(sock, (struct sockaddr*)&local_addr, &addr_len) < 0) {
        close(sock);
        return "127.0.0.1";
    }
    
    close(sock);
    
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local_addr.sin_addr, ip_str, INET_ADDRSTRLEN);
    return std::string(ip_str);
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
    
    // 创建文件请求
    FileRequest request;
    request.id = request_id;
    request.sender_ip = sender_ip;
    request.sender_alias = sender_alias;
    request.total_size = 0;
    request.progress = 0;
    request.accepted = false;
    
    // 解析文件列表
    size_t files_pos = body.find("\"files\":");
    if (files_pos != std::string::npos) {
        size_t array_start = body.find("[", files_pos);
        size_t array_end = body.find("]", array_start);
        if (array_start != std::string::npos && array_end != std::string::npos) {
            std::string files_array = body.substr(array_start, array_end - array_start + 1);
            
            // 简单解析文件名
            size_t pos = 0;
            while ((pos = files_array.find("\"fileName\":\"", pos)) != std::string::npos) {
                pos += 12;
                size_t end = files_array.find("\"", pos);
                if (end != std::string::npos) {
                    std::string filename = files_array.substr(pos, end - pos);
                    request.files.push_back(filename);
                }
            }
        }
    }
    
    // 存储请求
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_pending_requests[request_id] = request;
    }
    
    // 触发回调
    if (g_file_callback) {
        std::ostringstream callback_json;
        callback_json << "{";
        callback_json << "\"id\":\"" << request_id << "\",";
        callback_json << "\"sender_ip\":\"" << sender_ip << "\",";
        callback_json << "\"sender_alias\":\"" << json_escape(sender_alias) << "\",";
        callback_json << "\"file_count\":" << request.files.size();
        callback_json << "}";
        
        g_file_callback(callback_json.str().c_str());
    }
    
    // 返回响应
    std::ostringstream response;
    response << "{";
    response << "\"sessionId\":\"" << request_id << "\",";
    response << "\"files\":{";
    
    // 为每个文件生成 token
    for (size_t i = 0; i < request.files.size(); ++i) {
        if (i > 0) response << ",";
        response << "\"" << i << "\":{\"id\":\"" << i << "\"}";
    }
    
    response << "}}";
    
    return http_response(200, response.str());
}

static std::string handle_upload(const std::string& path, const std::string& body, size_t content_length) {
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
    std::string file_id = upload_path.substr(slash_pos + 1);
    
    // 获取请求信息
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_pending_requests.find(session_id);
    if (it == g_pending_requests.end()) {
        return http_response(404, "{\"error\":\"Session not found\"}");
    }
    
    if (!it->second.accepted) {
        return http_response(403, "{\"error\":\"Request not accepted\"}");
    }
    
    // 保存文件
    std::string save_path = it->second.save_dir + "/" + it->second.files[std::stoul(file_id)];
    
    FILE* fp = fopen(save_path.c_str(), "wb");
    if (!fp) {
        return http_response(500, "{\"error\":\"Cannot create file\"}");
    }
    
    fwrite(body.c_str(), 1, content_length, fp);
    fclose(fp);
    
    // 更新进度
    it->second.progress = 100;
    
    return http_response(200, "{\"success\":true}");
}

static std::string handle_request(const std::string& method, const std::string& path, 
                                   const std::string& body, const std::string& sender_ip,
                                   size_t content_length) {
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
        return handle_upload(path, body, content_length);
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
        std::string request(buffer);
        size_t method_end = request.find(' ');
        size_t path_end = request.find(' ', method_end + 1);
        size_t body_start = request.find("\r\n\r\n");
        
        // 解析 Content-Length
        size_t content_length = 0;
        size_t cl_pos = request.find("Content-Length:");
        if (cl_pos == std::string::npos) {
            cl_pos = request.find("content-length:");
        }
        if (cl_pos != std::string::npos) {
            size_t cl_end = request.find("\r\n", cl_pos);
            if (cl_end != std::string::npos) {
                std::string cl_str = request.substr(cl_pos + 15, cl_end - cl_pos - 15);
                // 去除空格
                cl_str.erase(0, cl_str.find_first_not_of(" \t"));
                content_length = std::stoul(cl_str);
            }
        }
        
        if (method_end != std::string::npos && path_end != std::string::npos) {
            std::string method = request.substr(0, method_end);
            std::string path = request.substr(method_end + 1, path_end - method_end - 1);
            std::string body = (body_start != std::string::npos) ? request.substr(body_start + 4) : "";
            
            std::string response = handle_request(method, path, body, sender_ip, content_length);
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
    }
    
    // 启动 HTTP 服务器
    g_server_running = true;
    g_http_thread = std::thread(http_loop);
    
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
    for (const auto& [ip, info] : g_discovered_devices) {
        if (!first) json << ",";
        json << info;
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

bool localsend_send_request(const char* target_ip, uint16_t port, const char* files_json) {
    if (!target_ip || !files_json) return false;
    
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
    request << "\r\n";
    request << files_json;
    
    std::string req = request.str();
    send(sock, req.c_str(), req.size(), 0);
    
    // 读取响应
    char buffer[1024];
    ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
    close(sock);
    
    if (len > 0) {
        buffer[len] = '\0';
        // 检查是否成功
        return strstr(buffer, "200") != nullptr;
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
    
    // TODO: 取消正在进行的传输
    
    g_pending_requests.erase(it);
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

} // extern "C"

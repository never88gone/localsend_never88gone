/**
 * LocalSend NAPI 接口定义
 * 
 * 这是 Rust 核心库的 TypeScript 类型定义
 */

// ============================================================================
// 服务器控制
// ============================================================================

/**
 * 启动 LocalSend 服务器
 * @param alias 设备别名
 * @param port 监听端口 (默认: 53317)
 * @returns 是否启动成功
 */
export const startServer: (alias: string, port: number) => boolean;

/**
 * 停止 LocalSend 服务器
 */
export const stopServer: () => void;

/**
 * 检查服务器是否运行
 * @returns 是否正在运行
 */
export const isServerRunning: () => boolean;

// ============================================================================
// 设备发现
// ============================================================================

/**
 * 扫描局域网设备
 * @returns JSON 字符串格式的设备列表
 * @example
 * const devices = JSON.parse(scanDevices()) as Device[];
 */
export const scanDevices: () => string;

/**
 * 发送 UDP 多播公告
 * @returns 是否发送成功
 */
export const sendAnnouncement: () => boolean;

/**
 * 获取已发现设备数量
 * @returns 设备数量
 */
export const getDeviceCount: () => number;

/**
 * 获取已注册设备 (通过 HTTP)
 * @returns JSON 字符串格式的设备列表
 */
export const getRegisteredDevices: () => string;

// ============================================================================
// 网络信息
// ============================================================================

/**
 * 获取本地网络信息
 * @returns JSON 字符串格式的网络信息
 * @example
 * const info = JSON.parse(getLocalNetworkInfo()) as NetworkInfo;
 */
export const getLocalNetworkInfo: () => string;

/**
 * 获取设备指纹
 * @returns 指纹字符串
 */
export const getFingerprint: () => string;

/**
 * 设置设备别名
 * @param alias 新别名
 * @returns 是否设置成功
 */
export const setAlias: (alias: string) => boolean;

// ============================================================================
// 文件传输
// ============================================================================

/**
 * 发送文件请求到目标设备
 * @param targetIp 目标设备 IP
 * @param port 目标设备端口
 * @param filesJson JSON 格式的文件列表
 * @returns 是否发送成功
 */
export const sendRequest: (targetIp: string, port: number, filesJson: string) => boolean;

/**
 * 获取待处理的文件请求
 * @returns JSON 字符串格式的请求列表
 */
export const getPendingRequests: () => string;

/**
 * 接受文件请求
 * @param requestId 请求 ID
 * @param saveDir 保存目录
 * @returns 是否接受成功
 */
export const acceptRequest: (requestId: string, saveDir: string) => boolean;

/**
 * 拒绝文件请求
 * @param requestId 请求 ID
 * @returns 是否拒绝成功
 */
export const rejectRequest: (requestId: string) => boolean;

/**
 * 获取接收进度
 * @param requestId 请求 ID
 * @returns 进度 (0-100), -1 表示错误
 */
export const getReceiveProgress: (requestId: string) => number;

/**
 * 取消传输
 * @param requestId 请求 ID
 * @returns 是否取消成功
 */
export const cancelTransfer: (requestId: string) => boolean;

/**
 * 设置设备发现回调
 * @param callback 回调函数
 */
export const setDeviceCallback: (callback: (deviceJson: string) => void) => void;

/**
 * 设置文件请求回调
 * @param callback 回调函数
 */
export const setFileCallback: (callback: (requestJson: string) => void) => void;

// ============================================================================
// 类型定义
// ============================================================================

/**
 * 设备信息
 */
export interface Device {
  ip: string;
  alias: string;
  version: string;
  port: number;
  https: boolean;
  fingerprint: string;
  deviceModel: string;
  deviceType: 'mobile' | 'desktop' | 'web' | 'headless' | 'tv';
  download: boolean;
}

/**
 * 网络信息
 */
export interface NetworkInfo {
  ip: string;
  port: number;
  multicastGroup: string;
  version: string;
  alias: string;
  fingerprint: string;
}

/**
 * 文件信息
 */
export interface FileInfo {
  id: string;
  fileName: string;
  size: number;
  fileType?: string;
  preview?: string;
}

/**
 * 发送请求
 */
export interface SendRequest {
  files: FileInfo[];
  requestId?: string;
}

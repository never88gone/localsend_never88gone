/**
 * LocalSend 核心服务
 * 
 * 封装 Rust NAPI 调用，提供类型安全的接口
 */

import native from 'libentry.so';
import wifiManager from '@ohos.wifiManager';

/**
 * 将整型 IP 地址格式化为点分十进制字符串，包含大小端自适应校验
 */
function formatIpAddress(ipAddress: number): string {
  if (ipAddress <= 0) {
    return '';
  }
  // 小端序字节提取
  const le0 = ipAddress & 0xFF;
  const le1 = (ipAddress >> 8) & 0xFF;
  const le2 = (ipAddress >> 16) & 0xFF;
  const le3 = (ipAddress >>> 24) & 0xFF;

  // 大端序字节提取
  const be0 = (ipAddress >>> 24) & 0xFF;
  const be1 = (ipAddress >> 16) & 0xFF;
  const be2 = (ipAddress >> 8) & 0xFF;
  const be3 = ipAddress & 0xFF;

  // 校验首字节是否为私有局域网IP常用开头 (192, 10, 172)
  const isPrivate = (firstByte: number): boolean => {
    return firstByte === 192 || firstByte === 10 || firstByte === 172;
  };

  if (isPrivate(le0) && !isPrivate(be0)) {
    return `${le0}.${le1}.${le2}.${le3}`;
  }
  if (isPrivate(be0) && !isPrivate(le0)) {
    return `${be0}.${be1}.${be2}.${be3}`;
  }
  // 默认使用小端 (对应 ARM/x86 鸿蒙设备)
  return `${le0}.${le1}.${le2}.${le3}`;
}

/**
 * 设备类型
 */
export enum DeviceType {
  Mobile = 'mobile',
  Desktop = 'desktop',
  Web = 'web',
  Headless = 'headless',
  Tv = 'tv'
}

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
  deviceType: DeviceType;
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
  filePath?: string;
  fd?: number;
}

/**
 * 接收到的请求信息
 */
export interface FileRequestInfo {
  id: string;
  senderIp: string;
  senderAlias: string;
  fingerprint?: string;
  fileCount: number;
  totalSize: number;
  files: FileInfo[]; // 增加详细文件列表
}

/**
 * 发送请求
 */
export interface SendRequest {
  files: FileInfo[];
  requestId?: string;
  senderAlias?: string;
}

/**
 * LocalSend 服务类
 */
export class LocalSendService {
  private static instance: LocalSendService | null = null;
  private _isRunning: boolean = false;
  private _alias: string = '糖葫芦投送';
  private _port: number = 53317;

  private deviceCallbacks: Set<(deviceJson: string) => void> = new Set();
  private fileCallbacks: Set<(requestJson: string) => void> = new Set();
  private progressCallbacks: Set<(id: string, progress: number) => void> = new Set();
  private isCallbacksInitialized: boolean = false;

  private constructor() {
    // 初始化时，如果 AppStorage 已经有了 PIN 码，同步到 C++
    try {
      const pin = AppStorage.get<string>('appPinCode');
      if (pin !== undefined) {
        native.setPinCode(pin);
        console.info(`[LocalSend] Initialized PIN code from AppStorage, length: ${pin.length}`);
      }
    } catch (e) {
      console.error('[LocalSend] Failed to initialize PIN code in constructor:', e);
    }
  }

  private initNativeCallbacks(): void {
    if (this.isCallbacksInitialized) {
      return;
    }
    try {
      native.setDeviceCallback((deviceJson: string) => {
        this.deviceCallbacks.forEach((cb) => {
          try {
            cb(deviceJson);
          } catch (e) {
            console.error('[LocalSend] Error in device callback:', e);
          }
        });
      });

      native.setFileCallback((requestJson: string) => {
        this.fileCallbacks.forEach((cb) => {
          try {
            cb(requestJson);
          } catch (e) {
            console.error('[LocalSend] Error in file callback:', e);
          }
        });
      });

      native.setProgressCallback((id: string, progress: number) => {
        this.progressCallbacks.forEach((cb) => {
          try {
            cb(id, progress);
          } catch (e) {
            console.error('[LocalSend] Error in progress callback:', e);
          }
        });
      });

      this.isCallbacksInitialized = true;
    } catch (error) {
      console.error('[LocalSend] Failed to initialize native callbacks:', error);
    }
  }

  registerDeviceCallback(callback: (deviceJson: string) => void): void {
    this.initNativeCallbacks();
    this.deviceCallbacks.add(callback);
  }

  unregisterDeviceCallback(callback: (deviceJson: string) => void): void {
    this.deviceCallbacks.delete(callback);
  }

  registerFileCallback(callback: (requestJson: string) => void): void {
    this.initNativeCallbacks();
    this.fileCallbacks.add(callback);
  }

  unregisterFileCallback(callback: (requestJson: string) => void): void {
    this.fileCallbacks.delete(callback);
  }

  registerProgressCallback(callback: (id: string, progress: number) => void): void {
    this.initNativeCallbacks();
    this.progressCallbacks.add(callback);
  }

  unregisterProgressCallback(callback: (id: string, progress: number) => void): void {
    this.progressCallbacks.delete(callback);
  }

  /**
   * 获取单例实例
   */
  static getInstance(): LocalSendService {
    if (!LocalSendService.instance) {
      LocalSendService.instance = new LocalSendService();
    }
    return LocalSendService.instance;
  }

  /**
   * 启动服务器
   */
  start(alias: string = this._alias, port: number = this._port): boolean {
    if (this._isRunning) {
      console.warn('[LocalSend] Server already running');
      return true;
    }

    let wifiIp = '';
    try {
      const ipInfo = wifiManager.getIpInfo();
      wifiIp = formatIpAddress(ipInfo.ipAddress);
      console.info('[LocalSend] wifiManager resolved WiFi IP:', wifiIp);
    } catch (wifiErr) {
      console.error('[LocalSend] Failed to resolve WiFi IP via wifiManager:', wifiErr);
    }

    try {
      const success = native.startServer(alias, port, wifiIp);
      if (success) {
        this._isRunning = true;
        this._alias = alias;
        this._port = port;
        console.info(`[LocalSend] Server started on port ${port} with IP ${wifiIp}`);
      }
      return success;
    } catch (error) {
      console.error('[LocalSend] Failed to start server:', error);
      return false;
    }
  }

  /**
   * 停止服务器
   */
  stop(): void {
    if (!this._isRunning) {
      return;
    }

    try {
      native.stopServer();
      this._isRunning = false;
      console.info('[LocalSend] Server stopped');
    } catch (error) {
      console.error('[LocalSend] Failed to stop server:', error);
    }
  }

  /**
   * 检查服务器是否运行
   */
  isRunning(): boolean {
    try {
      const running = native.isServerRunning();
      this._isRunning = running; // 同步状态
      return running;
    } catch {
      return this._isRunning;
    }
  }

  /**
   * 扫描设备
   */
  scanDevices(timeoutMs: number = 2000): Device[] {
    try {
      const json = native.scanDevices();
      return JSON.parse(json) as Device[];
    } catch (error) {
      console.error('[LocalSend] Failed to scan devices:', error);
      return [];
    }
  }

  /**
   * 发送公告
   */
  sendAnnouncement(): boolean {
    try {
      return native.sendAnnouncement();
    } catch (error) {
      console.error('[LocalSend] Failed to send announcement:', error);
      return false;
    }
  }

  /**
   * 获取已发现设备数量
   */
  getDeviceCount(): number {
    try {
      return native.getDeviceCount();
    } catch {
      return 0;
    }
  }

  /**
   * 获取已注册设备
   */
  getRegisteredDevices(): Device[] {
    try {
      const json = native.getRegisteredDevices();
      return JSON.parse(json) as Device[];
    } catch {
      return [];
    }
  }

  /**
   * 获取网络信息
   */
  getNetworkInfo(): NetworkInfo | null {
    try {
      const json = native.getLocalNetworkInfo();
      return JSON.parse(json) as NetworkInfo;
    } catch (error) {
      console.error('[LocalSend] Failed to get network info:', error);
      return null;
    }
  }

  /**
   * 获取设备指纹
   */
  getFingerprint(): string {
    try {
      return native.getFingerprint();
    } catch {
      return '';
    }
  }

  /**
   * 设置设备别名
   */
  setAlias(alias: string): boolean {
    try {
      const success = native.setAlias(alias);
      if (success) {
        this._alias = alias;
      }
      return success;
    } catch {
      return false;
    }
  }

  /**
   * 设置接收端 PIN 码
   */
  setPinCode(pin: string): void {
    try {
      native.setPinCode(pin);
      console.info(`[LocalSend] PIN code synchronized, length: ${pin.length}`);
    } catch (error) {
      console.error('[LocalSend] Failed to synchronize PIN code:', error);
    }
  }

  /**
   * 发送文件请求
   */
  sendRequest(targetIp: string, port: number, files: FileInfo[]): boolean {
    try {
      const filesJson = JSON.stringify(files);
      return native.sendRequest(targetIp, port, filesJson);
    } catch (error) {
      console.error('[LocalSend] Failed to send request:', error);
      return false;
    }
  }

  /**
   * 获取待处理请求
   */
  getPendingRequests(): SendRequest[] {
    try {
      const json = native.getPendingRequests();
      return JSON.parse(json) as SendRequest[];
    } catch {
      return [];
    }
  }

  /**
   * 接受文件请求
   */
  acceptRequest(requestId: string, saveDir: string): boolean {
    try {
      return native.acceptRequest(requestId, saveDir);
    } catch (error) {
      console.error('[LocalSend] Failed to accept request:', error);
      return false;
    }
  }

  /**
   * 拒绝文件请求
   */
  rejectRequest(requestId: string): boolean {
    try {
      return native.rejectRequest(requestId);
    } catch (error) {
      console.error('[LocalSend] Failed to reject request:', error);
      return false;
    }
  }

  /**
   * 获取接收进度 (0-100, -1 表示错误)
   */
  getReceiveProgress(requestId: string): number {
    try {
      return native.getReceiveProgress(requestId);
    } catch {
      return -1;
    }
  }

  /**
   * 取消传输
   */
  cancelTransfer(requestId: string): boolean {
    try {
      return native.cancelTransfer(requestId);
    } catch (error) {
      console.error('[LocalSend] Failed to cancel transfer:', error);
      return false;
    }
  }

  /**
   * 设置设备发现回调
   */
  setDeviceCallback(callback: (deviceJson: string) => void): void {
    this.registerDeviceCallback(callback);
  }

  /**
   * 设置文件请求回调
   */
  setFileRequestCallback(callback: (requestJson: string) => void): void {
    this.registerFileCallback(callback);
  }

  /**
   * 设置进度回调
   */
  setProgressCallback(callback: (id: string, progress: number) => void): void {
    this.registerProgressCallback(callback);
  }

  /**
   * 获取当前别名
   */
  get alias(): string {
    return this._alias;
  }

  /**
   * 获取当前端口
   */
  get port(): number {
    return this._port;
  }
}

// 导出单例
export const localSendService = LocalSendService.getInstance();

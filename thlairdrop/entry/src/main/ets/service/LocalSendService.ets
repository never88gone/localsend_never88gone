/**
 * LocalSend 核心服务
 * 
 * 封装 Rust NAPI 调用，提供类型安全的接口
 */

import native from 'libentry.so';

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
  private _alias: string = 'HarmonyOS Device';
  private _port: number = 53317;

  private constructor() {}

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

    try {
      const success = native.startServer(alias, port);
      if (success) {
        this._isRunning = true;
        this._alias = alias;
        this._port = port;
        console.info(`[LocalSend] Server started on port ${port}`);
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
    try {
      native.setDeviceCallback(callback);
    } catch (error) {
      console.error('[LocalSend] Failed to set device callback:', error);
    }
  }

  /**
   * 设置文件请求回调
   */
  setFileRequestCallback(callback: (requestJson: string) => void): void {
    try {
      native.setFileCallback(callback);
    } catch (error) {
      console.error('[LocalSend] Failed to set file callback:', error);
    }
  }

  /**
   * 设置进度回调
   */
  setProgressCallback(callback: (id: string, progress: number) => void): void {
    // TODO: 需要在 native 模块中实现 setProgressCallback
    console.warn('[LocalSend] setProgressCallback not implemented in native module');
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

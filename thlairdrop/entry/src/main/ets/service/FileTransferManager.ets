/**
 * 文件传输管理器
 * 
 * 管理文件传输状态、进度和回调
 */

import { localSendService, Device, FileInfo, SendRequest, DeviceType, FileRequestInfo } from './LocalSendService';
import { historyService, HistoryRecord } from '../services/HistoryService';
import { SettingsService } from '../services/SettingsService';
import vibrator from '@ohos.vibrator';
import fs from '@ohos.file.fs';

/**
 * 传输状态
 */
export enum TransferState {
  Pending = 'pending',
  InProgress = 'in_progress',
  Completed = 'completed',
  Failed = 'failed',
  Cancelled = 'cancelled'
}

/**
 * 传输方向
 */
export enum TransferDirection {
  Send = 'send',
  Receive = 'receive'
}

/**
 * 传输任务
 */
export interface TransferTask {
  id: string;
  direction: TransferDirection;
  state: TransferState;
  device: Device;
  files: FileInfo[];
  totalSize: number;
  transferredSize: number;
  progress: number;
  startTime: number;
  endTime?: number;
  speed: number; // 字节/秒
  eta: number;   // 剩余秒数
  saveDir?: string;
  errorMessage?: string;
}

/**
 * 传输回调
 */
export interface TransferCallback {
  onProgress?: (task: TransferTask) => void;
  onComplete?: (task: TransferTask) => void;
  onError?: (task: TransferTask, error: string) => void;
  onStateChanged?: (task: TransferTask) => void;
}

/**
 * 文件传输管理器
 */
export class FileTransferManager {
  private static instance: FileTransferManager | null = null;
  private tasks: Map<string, TransferTask> = new Map();
  private callbacks: Map<string, TransferCallback> = new Map();
  private listeners: ((tasks: TransferTask[]) => void)[] = [];
  private pollingIntervalId: number | null = null;

  private constructor() {
    this.initCallbacks();
  }

  /**
   * 注册任务更新监听器
   */
  public onUpdate(listener: (tasks: TransferTask[]) => void): void {
    this.listeners.push(listener);
    // 立即通知一次当前状态
    listener(this.getAllTasks());
  }

  /**
   * 移除监听器
   */
  public offUpdate(listener: (tasks: TransferTask[]) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    const allTasks = this.getAllTasks();
    this.listeners.forEach(l => l(allTasks));
  }

  /**
   * 初始化回调
   */
  private initCallbacks(): void {
    // 注册 NAPI 进度回调
    localSendService.setProgressCallback((id: string, progress: number) => {
      this.updateProgress(id, progress);
    });

    // 注册 NAPI 文件请求回调
    localSendService.setFileRequestCallback(async (json: string) => {
      try {
        const info = JSON.parse(json) as FileRequestInfo;
        
        // 创建任务（待处理状态）
        this.createReceiveTaskFromInfo(info);

        // 检查自动接受
        const settings = await SettingsService.getInstance().getSettings();
        const isFav = info.fingerprint ? settings.favorites.includes(info.fingerprint) : false;
        
        // 0: 关, 1: 收藏, 2: 总是
        if (settings.quickSaveMode === 2 || (settings.quickSaveMode === 1 && isFav)) {
          console.info(`[Transfer] Auto-accepting request from ${info.senderAlias}`);
          this.acceptReceiveTask(info.id);
        }
      } catch (e) {
        console.error('[Transfer] Failed to handle file request callback:', e);
      }
    });
  }

  /**
   * 获取单例实例
   */
  static getInstance(): FileTransferManager {
    if (!FileTransferManager.instance) {
      FileTransferManager.instance = new FileTransferManager();
    }
    return FileTransferManager.instance;
  }

  /**
   * 创建发送任务
   */
  createSendTask(device: Device, files: FileInfo[]): TransferTask {
    const taskId = this.generateTaskId();
    const totalSize = files.reduce((sum, f) => sum + f.size, 0);

    const task: TransferTask = {
      id: taskId,
      direction: TransferDirection.Send,
      state: TransferState.Pending,
      device: device,
      files: files,
      totalSize: totalSize,
      transferredSize: 0,
      progress: 0,
      startTime: Date.now(),
      speed: 0,
      eta: 0
    };

    this.tasks.set(taskId, task);
    return task;
  }

  /**
   * 创建接收任务
   */
  createReceiveTask(requestId: string, device: Device, files: FileInfo[], saveDir: string): TransferTask {
    const totalSize = files.reduce((sum, f) => sum + f.size, 0);

    const task: TransferTask = {
      id: requestId,
      direction: TransferDirection.Receive,
      state: TransferState.Pending,
      device: device,
      files: files,
      totalSize: totalSize,
      transferredSize: 0,
      progress: 0,
      startTime: Date.now(),
      saveDir: saveDir,
      speed: 0,
      eta: 0
    };

    this.tasks.set(requestId, task);
    return task;
  }

  /**
   * 从通知信息创建接收任务
   */
  private createReceiveTaskFromInfo(info: FileRequestInfo): void {
    const task: TransferTask = {
      id: info.id,
      direction: TransferDirection.Receive,
      state: TransferState.Pending,
      progress: 0,
      totalSize: info.totalSize,
      transferredSize: 0,
      startTime: Date.now(),
      files: info.files || [], // 使用传输过来的详细文件列表
      device: {
        ip: info.senderIp,
        alias: info.senderAlias,
        port: 53317,
        version: '1.0',
        https: false,
        fingerprint: info.fingerprint || '',
        deviceModel: 'Unknown',
        deviceType: DeviceType.Mobile,
        download: false
      },
      speed: 0,
      eta: 0
    };
    this.tasks.set(task.id, task);
  }

  /**
   * 取消传输任务
   */
  cancelTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    localSendService.cancelTransfer(taskId);
    this.updateTaskState(task, TransferState.Failed, '已取消');
  }

  /**
   * 接受接收任务
   */
  async acceptReceiveTask(taskId: string): Promise<boolean> {
    const task = this.tasks.get(taskId);
    if (!task || task.direction !== TransferDirection.Receive) return false;

    const settings = await SettingsService.getInstance().getSettings();
    const savePath = this.resolveSavePath(settings.saveDir);

    try {
      const success = localSendService.acceptRequest(taskId, savePath);
      if (success) {
        task.saveDir = savePath;
        this.updateTaskState(task, TransferState.InProgress);
        this.startPolling();
        return true;
      }
      return false;
    } catch (e) {
      this.updateTaskState(task, TransferState.Failed, String(e));
      return false;
    }
  }

  /**
   * 解析保存路径标签为真实绝对路径
   */
  private resolveSavePath(label: string): string {
    const context = SettingsService.getInstance().getContext();
    if (!context) {
      return '';
    }

    let subDir = 'Download';
    if (label === '图片') subDir = 'Pictures';
    else if (label === '文档') subDir = 'Documents';
    
    const baseDir = context.filesDir;
    const fullPath = `${baseDir}/${subDir}`;
    
    try {
      if (!fs.accessSync(fullPath)) {
        fs.mkdirSync(fullPath);
      }
    } catch (e) {
      console.error(`[Transfer] Failed to create directory ${fullPath}:`, e);
    }
    
    return fullPath;
  }
  /**
   * 启动发送任务
   */
  async startSendTask(taskId: string): Promise<boolean> {
    const task = this.tasks.get(taskId);
    if (!task || task.direction !== TransferDirection.Send) {
      return false;
    }

    this.updateTaskState(task, TransferState.InProgress);

    try {
      const success = localSendService.sendRequest(
        task.device.ip,
        task.device.port,
        task.files
      );

      if (success) {
        this.startPolling();
        return true;
      } else {
        this.updateTaskState(task, TransferState.Failed, '无法建立连接');
        return false;
      }
    } catch (error) {
      this.updateTaskState(task, TransferState.Failed, String(error));
      return false;
    }
  }

  /**
   * 接收文件请求
   */
  async acceptReceive(requestId: string, saveDir: string): Promise<boolean> {
    const success = localSendService.acceptRequest(requestId, saveDir);
    if (success) {
      const task = this.tasks.get(requestId);
      if (task) {
        this.updateTaskState(task, TransferState.InProgress);
      }
    }
    return success;
  }

  /**
   * 拒绝接收
   */
  rejectReceive(requestId: string): boolean {
    return localSendService.rejectRequest(requestId);
  }

  /**
   * 取消传输
   */
  cancelTransfer(taskId: string): boolean {
    const task = this.tasks.get(taskId);
    if (!task) return false;

    if (task.state === TransferState.InProgress) {
      localSendService.cancelTransfer(taskId);
    }

    this.updateTaskState(task, TransferState.Cancelled);
    return true;
  }

  /**
   * 获取任务
   */
  getTask(taskId: string): TransferTask | undefined {
    return this.tasks.get(taskId);
  }

  /**
   * 获取所有任务
   */
  getAllTasks(): TransferTask[] {
    return Array.from(this.tasks.values());
  }

  /**
   * 获取进行中的任务
   */
  getActiveTasks(): TransferTask[] {
    return this.getAllTasks().filter(
      t => t.state === TransferState.InProgress || t.state === TransferState.Pending
    );
  }

  /**
   * 注册回调
   */
  registerCallback(taskId: string, callback: TransferCallback): void {
    this.callbacks.set(taskId, callback);
  }

  /**
   * 移除回调
   */
  unregisterCallback(taskId: string): void {
    this.callbacks.delete(taskId);
  }

  /**
   * 清理已完成的任务
   */
  clearCompletedTasks(): void {
    this.tasks.forEach((task: TransferTask, id: string) => {
      if (task.state === TransferState.Completed ||
          task.state === TransferState.Failed ||
          task.state === TransferState.Cancelled) {
        this.tasks.delete(id);
        this.callbacks.delete(id);
      }
    });
    this.notifyListeners();
  }

  /**
   * 更新任务状态
   */
  private updateTaskState(task: TransferTask, state: TransferState, error?: string): void {
    const oldState = task.state;
    task.state = state;
    if (error) {
      task.errorMessage = error;
    }

    if (state === TransferState.Completed || 
        state === TransferState.Failed ||
        state === TransferState.Cancelled) {
      task.endTime = Date.now();
      
      // 保存到历史记录
      this.saveToHistory(task);

      // 触感反馈
      try {
        if (state === TransferState.Completed) {
          vibrator.startVibration({ type: 'time', duration: 50 }, { id: 0, usage: 'alarm' });
        } else if (state === TransferState.Failed) {
          vibrator.startVibration({ type: 'time', duration: 200 }, { id: 0, usage: 'alarm' });
        }
      } catch (e) {
        // 忽略不支持震动的设备
      }
    }

    const callback = this.callbacks.get(task.id);
    if (oldState !== state) {
      callback?.onStateChanged?.(task);
    }

    if (state === TransferState.Completed) {
      callback?.onComplete?.(task);
    } else if (state === TransferState.Failed) {
      callback?.onError?.(task, error || '未知错误');
    }

    this.notifyListeners();
  }

  /**
   * 保存到历史记录
   */
  private async saveToHistory(task: TransferTask): Promise<void> {
    const record: HistoryRecord = {
      id: task.id,
      fileName: task.files.length > 0 ? task.files[0].fileName : 'Unknown',
      size: task.totalSize,
      time: task.endTime || Date.now(),
      direction: task.direction === TransferDirection.Receive ? 'receive' : 'send',
      deviceName: task.device ? task.device.alias : 'Unknown',
      status: task.state === TransferState.Completed ? 'completed' : 'failed',
      filePath: task.direction === TransferDirection.Receive && task.saveDir 
        ? `${task.saveDir}/${task.files.length > 0 ? task.files[0].fileName : ''}`
        : (task.files.length > 0 ? task.files[0].filePath : undefined)
    };
    
    await historyService.addRecord(record);
  }

  /**
   * 更新进度
   */
  private updateProgress(taskId: string, progress: number): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    // 处理取消状态 (101)
    if (progress === 101) {
      this.updateTaskState(task, TransferState.Cancelled);
      return;
    }

    // 进度只增不减
    if (progress <= task.progress && progress < 100) return;

    task.progress = progress;
    task.transferredSize = Math.floor(task.totalSize * progress / 100);

    const callback = this.callbacks.get(taskId);
    callback?.onProgress?.(task);

    if (progress >= 100 && task.state === TransferState.InProgress) {
      this.updateTaskState(task, TransferState.Completed);
    } else {
      this.notifyListeners();
    }
  }

  /**
   * 启动进度轮询
   */
  private startPolling(): void {
    if (this.pollingIntervalId !== null) return;
    
    this.pollingIntervalId = setInterval(() => {
      const activeTasks = this.getActiveTasks();
      if (activeTasks.length === 0) {
        this.stopPolling();
        return;
      }
      
      activeTasks.forEach(task => {
        if (task.state === TransferState.InProgress) {
          const progress = localSendService.getReceiveProgress(task.id);
          if (progress >= 0 && progress <= 100) {
            this.updateProgress(task.id, progress);
          } else if (progress === -1) {
            this.updateTaskState(task, TransferState.Failed, '传输过程中出错');
          } else if (progress === 101) {
            this.updateTaskState(task, TransferState.Cancelled);
          }
        }
      });
    }, 500); // 每 500ms 轮询一次
  }

  /**
   * 停止进度轮询
   */
  private stopPolling(): void {
    if (this.pollingIntervalId !== null) {
      clearInterval(this.pollingIntervalId);
      this.pollingIntervalId = null;
    }
  }

  /**
   * 生成任务 ID
   */
  private generateTaskId(): string {
    return `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 销毁
   */
  destroy(): void {
    this.tasks.clear();
    this.callbacks.clear();
  }
}

// 导出单例
export const fileTransferManager = FileTransferManager.getInstance();


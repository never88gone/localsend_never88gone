/**
 * 文件传输管理器
 * 
 * 管理文件传输状态、进度和回调
 */

import { localSendService, Device, FileInfo, SendRequest } from './LocalSendService';

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
  saveDir?: string;
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
  private progressTimer: number = -1;

  private constructor() {
    this.startProgressMonitor();
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
      startTime: Date.now()
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
      saveDir: saveDir
    };

    this.tasks.set(requestId, task);
    return task;
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
        // 模拟进度更新（实际应该从 native 获取）
        this.simulateProgress(task);
        return true;
      } else {
        this.updateTaskState(task, TransferState.Failed);
        return false;
      }
    } catch (error) {
      this.updateTaskState(task, TransferState.Failed);
      const callback = this.callbacks.get(taskId);
      callback?.onError?.(task, String(error));
      return false;
    }
  }

  /**
   * 接收文件请求
   */
  async acceptReceive(requestId: string, saveDir: string): Promise<boolean> {
    const task = this.tasks.get(requestId);
    if (!task || task.direction !== TransferDirection.Receive) {
      // 创建新任务
      const pendingRequests = localSendService.getPendingRequests();
      // 找到对应的请求
      // 这里简化处理
    }

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
  }

  /**
   * 更新任务状态
   */
  private updateTaskState(task: TransferTask, state: TransferState): void {
    const oldState = task.state;
    task.state = state;

    if (state === TransferState.Completed || 
        state === TransferState.Failed ||
        state === TransferState.Cancelled) {
      task.endTime = Date.now();
    }

    const callback = this.callbacks.get(task.id);
    if (oldState !== state) {
      callback?.onStateChanged?.(task);
    }

    if (state === TransferState.Completed) {
      callback?.onComplete?.(task);
    }
  }

  /**
   * 更新进度
   */
  private updateProgress(taskId: string, progress: number): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    task.progress = progress;
    task.transferredSize = Math.floor(task.totalSize * progress / 100);

    const callback = this.callbacks.get(taskId);
    callback?.onProgress?.(task);

    if (progress >= 100) {
      this.updateTaskState(task, TransferState.Completed);
    }
  }

  /**
   * 启动进度监控
   */
  private startProgressMonitor(): void {
    // 每 500ms 检查一次进度
    this.progressTimer = setInterval(() => {
      this.tasks.forEach((task: TransferTask, id: string) => {
        if (task.state === TransferState.InProgress && 
            task.direction === TransferDirection.Receive) {
          const progress = localSendService.getReceiveProgress(id);
          if (progress >= 0 && progress !== task.progress) {
            this.updateProgress(id, progress);
          }
        }
      });
    }, 500);
  }

  /**
   * 模拟进度（用于发送）
   */
  private simulateProgress(task: TransferTask): void {
    let progress = 0;
    const interval = setInterval(() => {
      if (task.state !== TransferState.InProgress) {
        clearInterval(interval);
        return;
      }

      progress += Math.random() * 10;
      if (progress >= 100) {
        progress = 100;
        clearInterval(interval);
      }

      this.updateProgress(task.id, progress);
    }, 200);
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
    if (this.progressTimer !== -1) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
    this.tasks.clear();
    this.callbacks.clear();
  }
}

// 导出单例
export const fileTransferManager = FileTransferManager.getInstance();

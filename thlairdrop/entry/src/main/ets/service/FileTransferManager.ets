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
import fileUri from '@ohos.file.fileuri';
import common from '@ohos.app.ability.common';
import { rcp } from '@kit.RemoteCommunicationKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import environment from '@ohos.file.environment';
import deviceInfo from '@ohos.deviceInfo';
import promptAction from '@ohos.promptAction';
import { t } from '../utils/I18nManager';

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
    localSendService.registerProgressCallback((id: string, progress: number) => {
      this.updateProgress(id, progress);
    });

    // 注册 NAPI 文件请求回调
    localSendService.registerFileCallback(async (json: string) => {
      try {
        interface RawFileInfo {
          id?: string;
          fileName?: string;
          file_name?: string;
          size?: number;
          fileType?: string;
        }

        interface RawFileRequestJson {
          id: string;
          sender_ip?: string;
          sender_alias?: string;
          sender_fingerprint?: string;
          file_count?: number;
          total_size?: number;
          files?: Array<RawFileInfo>;
        }

        const raw = JSON.parse(json) as RawFileRequestJson;
        
        const files: FileInfo[] = (raw.files || []).map((f: RawFileInfo): FileInfo => {
          return {
            id: f.id || '',
            fileName: f.fileName || f.file_name || 'unknown',
            size: f.size || 0,
            fileType: f.fileType || ''
          } as FileInfo;
        });

        const info: FileRequestInfo = {
          id: raw.id,
          senderIp: raw.sender_ip || '',
          senderAlias: raw.sender_alias || 'Unknown',
          fingerprint: raw.sender_fingerprint || '',
          fileCount: raw.file_count || files.length,
          totalSize: raw.total_size !== undefined ? raw.total_size : files.reduce((sum, f) => sum + f.size, 0),
          files: files
        };

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

  cancelTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    if (task.direction === TransferDirection.Send) {
      // 发送任务由 RCP 异步循环监听此状态进行退出，这里直接更新状态即可
      this.updateTaskState(task, TransferState.Cancelled);
    } else {
      localSendService.cancelTransfer(taskId);
      this.updateTaskState(task, TransferState.Failed, '已取消');
    }
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
  public resolveSavePath(label: string): string {
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
      let exists = false;
      try {
        exists = fs.accessSync(fullPath);
      } catch (err) {
        exists = false;
      }
      if (!exists) {
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

    // 异步执行 RCP 发送任务，本方法同步返回 true 以启动流程
    this.startSendTaskRcp(task);
    return true;
  }

  /**
   * 异步使用 RCP 进行局域网 HTTP/HTTPS 发送
   */
  private async startSendTaskRcp(task: TransferTask): Promise<void> {
    this.updateTaskState(task, TransferState.InProgress);
    
    let session: rcp.Session | null = null;
    let totalSentAll = 0;
    try {
      // 1. 创建安全配置，跳过自签名证书校验，用于初始化握手阶段
      const config: rcp.SessionConfiguration = {
        requestConfiguration: {
          security: {
            remoteValidation: 'skip'
          },
          transfer: {
            timeout: {
              connectMs: 5000,
              transferMs: 300000
            }
          }
        }
      };
      
      session = rcp.createSession(config);
      
      const protocol = task.device.https ? 'https' : 'http';
      const baseUrl = `${protocol}://${task.device.ip}:${task.device.port}`;
      
      // 2. 准备握手数据
      interface HandshakeInfo {
        alias: string;
        version: string;
        deviceModel: string;
        deviceType: string;
        fingerprint: string;
        port: number;
        protocol: string;
        download: boolean;
      }

      interface HandshakeFile {
        id: string;
        fileName: string;
        size: number;
        fileType: string;
      }

      interface HandshakeRequestBody {
        info: HandshakeInfo;
        files: Record<string, HandshakeFile>;
      }

      const filesMap: Record<string, HandshakeFile> = {};
      
      task.files.forEach(f => {
        // 根据后缀名推导 MIME-Type 
        let ext = '';
        const dot = f.fileName.lastIndexOf('.');
        if (dot !== -1) {
          ext = f.fileName.substring(dot + 1).toLowerCase();
        }
        let mime = 'application/octet-stream';
        if (ext === 'jpg' || ext === 'jpeg') mime = 'image/jpeg';
        else if (ext === 'png') mime = 'image/png';
        else if (ext === 'gif') mime = 'image/gif';
        else if (ext === 'mp4') mime = 'video/mp4';
        else if (ext === 'mp3') mime = 'audio/mpeg';
        else if (ext === 'txt') mime = 'text/plain';
        else if (ext === 'pdf') mime = 'application/pdf';

        filesMap[f.id] = {
          id: f.id,
          fileName: f.fileName,
          size: f.size,
          fileType: mime
        };
      });

      const requestBody: HandshakeRequestBody = {
        info: {
          alias: localSendService.alias,
          version: '2.0',
          deviceModel: 'HarmonyOS',
          deviceType: 'mobile',
          fingerprint: localSendService.getFingerprint(),
          port: localSendService.port,
          protocol: 'http', // 本端接收端口依然是普通的 http
          download: false
        },
        files: filesMap
      };

      console.info(`[Transfer] RCP Sending prepare-upload to ${baseUrl}/api/localsend/v2/prepare-upload`);
      
      const prepareConfig: rcp.Configuration = {
        security: {
          remoteValidation: 'skip'
        },
        transfer: {
          timeout: {
            connectMs: 5000,
            transferMs: 300000
          }
        }
      };



      const prepareReq = new rcp.Request(`${baseUrl}/api/localsend/v2/prepare-upload`, 'POST', {
        'content-type': 'application/json'
      });
      prepareReq.content = JSON.stringify(requestBody);
      prepareReq.configuration = prepareConfig;

      const prepareRes = await session.fetch(prepareReq);

      if (prepareRes.statusCode !== 200) {
        throw new Error(`握手请求被拒绝: ${prepareRes.statusCode}`);
      }

      interface HandshakeResponseJson {
        sessionId?: string;
        id?: string;
        files?: Record<string, string>;
      }

      const resJson = prepareRes.toJSON() as HandshakeResponseJson;
      console.info(`[Transfer] 握手请求成功，返回的原始 JSON 数据: ${JSON.stringify(resJson)}`);

      const sessionId: string | undefined = resJson.sessionId || resJson.id;
      if (!sessionId) {
        throw new Error('未能从对端响应中解析出 sessionId');
      }

      console.info(`[Transfer] RCP Handshake successful, sessionId: ${sessionId}`);

      // 3. 循环发送每一个文件
      for (let i = 0; i < task.files.length; i++) {
        // 随时检查任务是否在上一周期被用户取消了
        if (task.state === TransferState.Cancelled || task.state === TransferState.Failed) {
          console.warn(`[Transfer] 检测到任务状态已被用户取消或置为失败，终止发送流程`);
          break;
        }

        const file = task.files[i];
        console.info(`[Transfer] =======================================`);
        console.info(`[Transfer] 开始发送第 ${i + 1}/${task.files.length} 个文件: ${file.fileName}`);
        console.info(`[Transfer] 待发送文件的本地缓存路径: ${file.filePath}`);
        console.info(`[Transfer] 预设文件大小: ${file.size} 字节`);

        if (!file.filePath) {
          console.warn(`[Transfer] 警告：File ${file.fileName} lacks filePath, skipping`);
          continue;
        }

        // 强校验物理文件存在性与大小
        try {
          const exists = fs.accessSync(file.filePath);
          console.info(`[Transfer] 本地物理文件存在性校验: ${exists}`);
          if (exists) {
            const realStat = fs.statSync(file.filePath);
            console.info(`[Transfer] 本地物理文件实际大小: ${realStat.size} 字节，与预设大小 ${file.size} 的比对差值: ${realStat.size - file.size}`);
          } else {
            console.error(`[Transfer] 错误：文件在物理磁盘上竟然不存在！路径为: ${file.filePath}`);
          }
        } catch (err) {
          console.error(`[Transfer] 物理文件存在性校验抛出异常: ${(err as Error).message}`);
        }

        const fileToken = resJson.files ? resJson.files[file.id] : undefined;
        console.info(`[Transfer] 文件 id: ${file.id}，从对端拿到的授权 Token: ${fileToken || '未找到'}`);

        let uploadUrl = `${baseUrl}/api/localsend/v2/upload?sessionId=${sessionId}&fileId=${file.id}`;
        if (fileToken) {
          uploadUrl += `&token=${fileToken}`;
        }
        console.info(`[Transfer] 构造完成的文件物理上传 URL: ${uploadUrl}`);

        let fileSession: rcp.Session | null = null;
        let uploadFileHandle: fs.File | null = null;
        let fileSentSize = 0;
        try {
          const fileSessionConfig: rcp.SessionConfiguration = {
            headers: {
              'content-length': file.size.toString(),
              'content-type': 'application/octet-stream'
            },
            requestConfiguration: {
              security: {
                remoteValidation: 'skip'
              },
              transfer: {
                timeout: {
                  connectMs: 5000,
                  transferMs: 3600000 // 1小时超时
                }
              },
              tracing: {
                httpEventsHandler: {
                  onUploadProgress: (total: number, transferred: number) => {
                    if (task.state === TransferState.Cancelled || task.state === TransferState.Failed) {
                      throw new Error('Cancelled by user');
                    }
                    const delta = transferred - fileSentSize;
                    fileSentSize = transferred;
                    totalSentAll += delta;
                    task.transferredSize = totalSentAll;

                    if (task.totalSize > 0) {
                      const currentProgress = Math.floor(totalSentAll * 100 / task.totalSize);
                      if (currentProgress !== task.progress && currentProgress < 100) {
                        task.progress = currentProgress;
                      }
                    }

                    const elapsed = (Date.now() - task.startTime) / 1000;
                    if (elapsed > 0) {
                      task.speed = totalSentAll / elapsed;
                      if (task.speed > 0) {
                        task.eta = Math.max(0, (task.totalSize - totalSentAll) / task.speed);
                      }
                    }
                    this.notifyListeners();
                  }
                }
              }
            }
          };

          console.info(`[Transfer] 正在为当前文件创建专属的 fileSession...`);
          fileSession = rcp.createSession(fileSessionConfig);
          
          console.info(`[Transfer] 正在尝试打开本地文件句柄...`);
          uploadFileHandle = fs.openSync(file.filePath, fs.OpenMode.READ_ONLY);
          console.info(`[Transfer] 本地文件句柄成功打开，系统的 fd 是: ${uploadFileHandle.fd}`);

          const uploadFile = new rcp.UploadFromFile(uploadFileHandle.fd);
          
          console.info(`[Transfer] 正在通过原生 fileSession.uploadFromFile 进行流式上传...`);
          const uploadRes = await fileSession.uploadFromFile(uploadUrl, uploadFile);
          console.info(`[Transfer] RCP 物理上传完成，对端返回响应状态码: ${uploadRes.statusCode}`);

          if (uploadRes.statusCode !== 200) {
            throw new Error(`文件 ${file.fileName} 上传失败，对端返回: ${uploadRes.statusCode}`);
          }
        } catch (fetchErr) {
          const errMsg = (fetchErr as Error).stack || (fetchErr as Error).message || String(fetchErr);
          console.error(`[Transfer] 物理上传过程中发生错误: ${errMsg}`);
          throw new Error(errMsg);
        } finally {
          if (uploadFileHandle) {
            try {
              console.info(`[Transfer] 正在关闭文件句柄 (fd: ${uploadFileHandle.fd})...`);
              fs.closeSync(uploadFileHandle);
              console.info(`[Transfer] 文件句柄成功关闭`);
            } catch (e) {
              console.error('[Transfer] 警告：关闭文件句柄失败:', e);
            }
          }
          if (fileSession) {
            try {
              console.info(`[Transfer] 正在关闭专属 fileSession...`);
              fileSession.close();
              console.info(`[Transfer] 专属 fileSession 成功关闭`);
            } catch (e) {
              console.error('[Transfer] 警告：关闭专属 fileSession 失败:', e);
            }
          }
        }

        // 文件完美传输完毕，更新已发总大小
        totalSentAll += file.size;
        task.transferredSize = totalSentAll;
        this.notifyListeners();
      }

      // 4. 收尾工作
      if (task.state === TransferState.Cancelled) {
        console.info(`[Transfer] Upload task ${task.id} finished with Cancelled state`);
      } else {
        task.progress = 100;
        task.transferredSize = task.totalSize;
        this.updateTaskState(task, TransferState.Completed);
        console.info(`[Transfer] Upload task ${task.id} completed successfully`);
      }

    } catch (err) {
      const fullErrorMsg = (err as Error).stack || (err as Error).message || String(err);
      if (task.state === TransferState.Cancelled) {
        console.info(`[Transfer] Upload task ${task.id} was cancelled, ignoring catch error: ${fullErrorMsg}`);
      } else {
        console.error(`[Transfer] Upload task ${task.id} failed:`, fullErrorMsg);
        this.updateTaskState(task, TransferState.Failed, fullErrorMsg);
      }
    } finally {
      if (session) {
        try {
          session.close();
        } catch (e) {
          console.error('[Transfer] Failed to close RCP session:', e);
        }
      }
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
        task.saveDir = saveDir;
        this.updateTaskState(task, TransferState.InProgress);
        this.startPolling();
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
      if (task.direction === TransferDirection.Receive) {
        // 自动保存到相册/公共目录
        this.exportReceivedFiles(task);
        try {
          promptAction.showToast({ message: t('receive_complete') });
        } catch (e) {
          console.error('[Transfer] Failed to show complete toast:', e);
        }
      }
    } else if (state === TransferState.Failed) {
      callback?.onError?.(task, error || '未知错误');
      if (task.direction === TransferDirection.Receive) {
        try {
          promptAction.showToast({ message: `${t('receive_failed')}: ${error || '未知错误'}` });
        } catch (e) {
          console.error('[Transfer] Failed to show error toast:', e);
        }
      }
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

    // 处理失败状态 (-1)
    if (progress === -1) {
      this.updateTaskState(task, TransferState.Failed, '传输过程中出错');
      return;
    }

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
          // 发送任务的进度由 RCP 在 TS 侧自动实时管理与回调，无需也无法向 C++ 轮询（否则找不到 sessionId 会报错 -1）
          if (task.direction === TransferDirection.Send) {
            return;
          }
          
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
   * 当文件接收完成时，根据用户设置导出到公共目录
   */
  private async exportReceivedFiles(task: TransferTask): Promise<void> {
    if (task.direction !== TransferDirection.Receive) return;

    try {
      const settings = await SettingsService.getInstance().getSettings();
      const saveDirSetting = settings.saveDir; // '下载' | '图片' | '文档'
      console.info(`[Transfer] Starting to export received files to: ${saveDirSetting}`);

      for (const file of task.files) {
        const srcPath = `${task.saveDir}/${file.fileName}`;
        
        // 检查源文件是否存在
        try {
          if (!fs.accessSync(srcPath)) {
            console.warn(`[Transfer] Source file not found: ${srcPath}`);
            continue;
          }
        } catch (err) {
          console.warn(`[Transfer] Cannot access source file: ${srcPath}`);
          continue;
        }

        const dot = file.fileName.lastIndexOf('.');
        let ext = 'jpg';
        if (dot !== -1) {
          ext = file.fileName.substring(dot + 1).toLowerCase();
        }
        const isImageOrVideo = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'mp4', 'mov', 'avi', 'mkv', '3gp'].includes(ext);

        if (isImageOrVideo) {
          // 只要是图片或者视频文件，直接尝试自动保存到系统相册中，获得最佳移动端体验
          await this.saveToGalleryInternal(srcPath, file.fileName, ext);
        } else {
          // 非媒体文件：先判断当前是否为手机，避免直接在手机上调用getUserDownloadDir导致系统抛出不支持的异常
          if (deviceInfo.deviceType === 'phone') {
            console.info(`[Transfer] Phone device detected, keeping non-media file '${file.fileName}' safely in sandbox. Use history picker to export manually.`);
          } else {
            try {
              let publicDir = '';
              if (saveDirSetting === '下载') {
                publicDir = environment.getUserDownloadDir();
              } else if (saveDirSetting === '文档') {
                publicDir = environment.getUserDocumentDir();
              }

              if (publicDir) {
                const destPath = `${publicDir}/${file.fileName}`;
                let srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
                let destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
                await fs.copyFile(srcFile.fd, destFile.fd);
                fs.closeSync(srcFile);
                fs.closeSync(destFile);
                console.info(`[Transfer] Successfully auto-exported non-media to public dir: ${destPath}`);
                promptAction.showToast({ message: `已保存至公共 ${saveDirSetting} 目录` });
              }
            } catch (e) {
              console.warn(`[Transfer] Auto-export to public ${saveDirSetting} dir not supported, keeping in sandbox.`);
            }
          }
        }
      }
    } catch (globalErr) {
      console.error('[Transfer] Global error in exportReceivedFiles:', globalErr);
    }
  }

  /**
   * 保存到系统相册内部方法
   */
  private async saveToGalleryInternal(filePath: string, fileName: string, ext: string): Promise<boolean> {
    const context = SettingsService.getInstance().getContext() as common.UIAbilityContext;
    if (!context) return false;

    try {
      const phAccessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const isVideo = ['mp4', 'mov', 'avi', 'mkv', '3gp'].includes(ext);
      const photoType: photoAccessHelper.PhotoType = isVideo ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE;

      const srcFileUris = ['file://' + filePath];
      const dot = fileName.lastIndexOf('.');
      const title = fileName.substring(0, dot !== -1 ? dot : fileName.length);
      const photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [{
        title: title,
        fileNameExtension: ext,
        photoType: photoType,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      }];

      const desFileUris: Array<string> = await phAccessHelper.showAssetsCreationDialog(srcFileUris, photoCreationConfigs);
      if (desFileUris && desFileUris.length > 0) {
        const targetUri: string = desFileUris[0];
        let srcFile = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
        let destFile = fs.openSync(targetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.copyFile(srcFile.fd, destFile.fd);
        fs.closeSync(srcFile);
        fs.closeSync(destFile);
        console.info(`[Transfer] Saved image to gallery: ${targetUri}`);
        promptAction.showToast({ message: '已成功保存至系统相册' });
        return true;
      }
    } catch (err) {
      console.error('[Transfer] Failed to save to gallery:', err);
    }
    return false;
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


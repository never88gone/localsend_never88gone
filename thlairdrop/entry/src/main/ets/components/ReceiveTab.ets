import promptAction from '@ohos.promptAction';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { localSendService, Device, FileInfo, DeviceType } from '../service/LocalSendService';
import { TransferProgressCard, TransferList } from './TransferProgressCard';

// 文件请求信息
interface FileRequestInfo {
  device: Device;
  files: FileInfo[];
  totalSize: number;
}

// JSON 解析结果
interface FileRequestJson {
  id: string;
  sender_ip?: string;
  sender_port?: number;
  sender_alias?: string;
  sender_fingerprint?: string;
  device_model?: string;
  download?: boolean;
  version?: string;
  https?: boolean;
  files?: FileItemJson[];
}

interface FileItemJson {
  id?: string;
  file_name?: string;
  fileName?: string;
  size?: number;
}

@Component
export struct ReceiveTab {
  @Link aliasName: string;
  @Link isServerRunning: boolean;
  @Link localIps: string[];
  @Link quickSaveMode: number;
  @Link showAdvancedInfo: boolean;
  @Link animationAngle: number;
  @State receiveTasks: TransferTask[] = [];
  @State pendingRequests: Map<string, FileRequestInfo> = new Map();

  aboutToAppear() {
    // 注册文件请求回调
    localSendService.setFileRequestCallback((requestJson: string) => {
      this.handleFileRequest(requestJson);
    });

    // 定期更新任务列表
    setInterval(() => {
      this.updateTasks();
    }, 500);
  }

  private handleFileRequest(requestJson: string) {
    try {
      const request: FileRequestJson = JSON.parse(requestJson) as FileRequestJson;
      const device: Device = {
        ip: request.sender_ip || '',
        port: request.sender_port || 53317,
        alias: request.sender_alias || 'Unknown',
        fingerprint: request.sender_fingerprint || '',
        deviceModel: request.device_model || 'Unknown',
        download: request.download || false,
        version: request.version || '2.0',
        https: request.https || false,
        deviceType: DeviceType.Mobile
      };

      const files: FileInfo[] = (request.files || []).map((f: FileItemJson): FileInfo => ({
        id: f.id || '',
        fileName: f.file_name || f.fileName || 'unknown',
        size: f.size || 0
      }));

      const totalSize = files.reduce((sum: number, f: FileInfo) => sum + f.size, 0);

      const info: FileRequestInfo = { device, files, totalSize };
      this.pendingRequests.set(request.id, info);
    } catch (e) {
      console.error('Failed to parse file request:', e);
    }
  }

  private updateTasks() {
    const allTasks = fileTransferManager.getAllTasks();
    this.receiveTasks = allTasks.filter(t => t.direction === TransferDirection.Receive);
  }

  private async acceptRequest(requestId: string) {
    const request = this.pendingRequests.get(requestId);
    if (!request) return;

    // 创建接收任务
    const saveDir = '/data/storage/el2/base/files/localsend';
    const task = fileTransferManager.createReceiveTask(
      requestId,
      request.device,
      request.files,
      saveDir
    );

    // 注册回调
    fileTransferManager.registerCallback(task.id, {
      onProgress: (t: TransferTask) => {
        this.updateTasks();
      },
      onComplete: (t: TransferTask) => {
        this.updateTasks();
        promptAction.showToast({ message: '文件接收完成！' });
      },
      onError: (t: TransferTask, error: string) => {
        this.updateTasks();
        promptAction.showToast({ message: `接收失败: ${error}` });
      }
    });

    // 接受请求
    const success = await fileTransferManager.acceptReceive(requestId, saveDir);
    if (success) {
      this.pendingRequests.delete(requestId);
      promptAction.showToast({ message: '开始接收文件...' });
    } else {
      promptAction.showToast({ message: '接受请求失败' });
    }
  }

  private rejectRequest(requestId: string) {
    fileTransferManager.rejectReceive(requestId);
    this.pendingRequests.delete(requestId);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 右上角按钮
      Row() {
        Button({ type: ButtonType.Circle }) {
          Path()
            .width(24)
            .height(24)
            .commands('M13,3 L13,11 L19,11 L19,13 L11,13 L11,3 L13,3 Z M12,21 C7.03,21 3,16.97 3,12 C3,7.03 7.03,3 12,3 L12,1 C5.92,1 1,5.92 1,12 C1,18.08 5.92,23 12,23 C18.08,23 23,18.08 23,12 L21,12 C21,16.97 16.97,21 12,21 Z')
            .fill('#666666')
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .margin({ right: 10 })
        .onClick(() => {
          // 显示传输历史
          if (this.receiveTasks.length > 0) {
            promptAction.showToast({ message: `有 ${this.receiveTasks.length} 个传输记录` });
          } else {
            promptAction.showToast({ message: '暂无接收历史' });
          }
        })

        Button({ type: ButtonType.Circle }) {
          Path()
            .width(24)
            .height(24)
            .commands('M12,2 C6.48,2 2,6.48 2,12 C2,17.52 6.48,22 12,22 C17.52,22 22,17.52 22,12 C22,6.48 17.52,2 12,2 Z M13,17 L11,17 L11,11 L13,11 L13,17 Z M13,9 L11,9 L11,7 L13,7 L13,9 Z')
            .fill('#666666')
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showAdvancedInfo = !this.showAdvancedInfo;
        })
      }
      .margin({ top: 40, right: 20 })
      .zIndex(1)

      Column() {
        // Logo & 雷达部分
        Column() {
          Stack() {
            // 背景扩散环 (优化: 使用透明度渐变)
            ForEach([1, 2, 3], (i: number) => {
              Circle()
                .width(120 + (this.animationAngle % 360 / 3.6) * i)
                .height(120 + (this.animationAngle % 360 / 3.6) * i)
                .fill(Color.Transparent)
                .stroke(i === 1 ? '#007DFF' : '#33007DFF')
                .strokeWidth(2)
                .opacity(Math.max(0, 1 - (this.animationAngle % 360 / 360) * (i/1.5)))
            })

            Image($r('app.media.app_icon'))
              .width(100)
              .height(100)
              .borderRadius(20)
          }
          .width(200)
          .height(200)
          .alignContent(Alignment.Center)
          .margin({ top: 80, bottom: 40 })
          
          Text(this.aliasName)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
          
          Toggle({ type: ToggleType.Switch, isOn: this.isServerRunning })
            .margin({ top: 10 })
            .onChange((isOn: boolean) => {
              this.isServerRunning = isOn;
              if (isOn) {
                localSendService.start(this.aliasName);
              } else {
                localSendService.stop();
              }
            })
          
          Text(this.isServerRunning ? this.localIps.map(ip => '#' + ip.split('.').pop()).join(' ') : '离线')
            .fontSize(18)
            .fontColor(Color.Gray)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // 待接收请求
        if (this.pendingRequests.size > 0) {
          Column() {
            Text('待接收文件')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 12 })

            ForEach(Array.from(this.pendingRequests.entries()), (entry: [string, FileRequestInfo]) => {
              Column() {
                Row() {
                  Text(entry[1].device.alias)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  
                  Blank()
                  
                  Text(this.formatSize(entry[1].totalSize))
                    .fontSize(14)
                    .fontColor(Color.Gray)
                }
                .width('100%')
                .margin({ bottom: 8 })

                Text(`${entry[1].files.length} 个文件`)
                  .fontSize(14)
                  .fontColor(Color.Gray)
                  .width('100%')
                  .margin({ bottom: 12 })

                Row() {
                  Button('拒绝')
                    .fontSize(14)
                    .fontColor('#F44336')
                    .backgroundColor('#1AF44336')
                    .borderRadius(8)
                    .onClick(() => this.rejectRequest(entry[0]))

                  Blank()

                  Button('接收')
                    .fontSize(14)
                    .fontColor('#4CAF50')
                    .backgroundColor('#1A4CAF50')
                    .borderRadius(8)
                    .onClick(() => this.acceptRequest(entry[0]))
                }
                .width('100%')
              }
              .width('90%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20 })
        }

        // 传输进度
        if (this.receiveTasks.length > 0) {
          Column() {
            Text('传输中')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 12 })

            ForEach(this.receiveTasks, (task: TransferTask) => {
              TransferProgressCard({
                task: task,
                onCancel: (taskId: string) => {
                  fileTransferManager.cancelTransfer(taskId);
                  this.updateTasks();
                }
              })
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20 })
        }

        // 高级信息卡片
        if (this.showAdvancedInfo) {
          Column() {
            Row() {
              Text('别名').width('30%').fontColor(Color.Gray)
              Text(this.aliasName)
            }.width('100%').margin({ bottom: 10 })
            
            Row() {
              Text('IP 地址').width('30%').fontColor(Color.Gray)
              Column() {
                ForEach(this.localIps, (ip: string) => {
                  Text(ip)
                })
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').margin({ bottom: 10 })
            
            Row() {
              Text('端口').width('30%').fontColor(Color.Gray)
              Text('53317')
            }.width('100%')
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin({ top: 20 })
          .shadow({ radius: 10, color: '#1A000000' })
        }

        Blank()

        // 快速保存
        Column() {
          Text('快速保存')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ bottom: 10 })
          
          Row() {
            this.QuickSaveButton('关闭', 0)
            this.QuickSaveButton('收藏', 1)
            this.QuickSaveButton('开启', 2)
          }
          .width('100%')
          .height(40)
          .backgroundColor('#E9E9E9')
          .borderRadius(20)
          .padding(2)
        }
        .width('80%')
        .margin({ bottom: 40 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder QuickSaveButton(label: string, index: number) {
    Text(label)
      .layoutWeight(1)
      .height('100%')
      .textAlign(TextAlign.Center)
      .fontSize(14)
      .fontColor(this.quickSaveMode === index ? Color.Black : Color.Gray)
      .backgroundColor(this.quickSaveMode === index ? Color.White : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        this.quickSaveMode = index;
      })
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}

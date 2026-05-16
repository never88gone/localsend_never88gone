import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { localSendService, Device, FileInfo, DeviceType } from '../service/LocalSendService';
import { TransferProgressCard } from './TransferProgressCard';
import { SettingsService } from '../services/SettingsService';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

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
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @State themeRefreshKey: number = 0;
  @Link aliasName: string;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  
  onRefreshTriggered() {
    this.themeRefreshKey = this.themeVersion + this.languageVersion;
  }
  @Link isServerRunning: boolean;
  @Link localIps: string[];
  @Link quickSaveMode: number;
  @Link showAdvancedInfo: boolean;
  @Link animationAngle: number;
  @Link saveDir: string;
  @Link port: number;
  @State receiveTasks: TransferTask[] = [];
  @State pendingRequests: Map<string, FileRequestInfo> = new Map();
  
  private settingsService: SettingsService = SettingsService.getInstance();
  private taskUpdateListener = (tasks: TransferTask[]) => {
    this.receiveTasks = tasks.filter(t => t.direction === TransferDirection.Receive);
  };

  aboutToAppear() {
    // 注册文件请求回调
    localSendService.setFileRequestCallback((requestJson: string) => {
      this.handleFileRequest(requestJson);
    });

    // 注册任务更新监听器
    fileTransferManager.onUpdate(this.taskUpdateListener);
  }

  aboutToDisappear() {
    fileTransferManager.offUpdate(this.taskUpdateListener);
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
    let actualDir = '/data/storage/el2/base/files/Download';
    if (this.saveDir === '文档' || this.saveDir === 'Documents') {
      actualDir = '/data/storage/el2/base/files/Documents';
    } else if (this.saveDir === '图片' || this.saveDir === 'Pictures') {
      actualDir = '/data/storage/el2/base/files/Pictures';
    }
    const task = fileTransferManager.createReceiveTask(
      requestId,
      request.device,
      request.files,
      actualDir
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
    const success = await fileTransferManager.acceptReceive(requestId, actualDir);
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
        // 历史记录按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(24)
            .fontColor([gc('text_secondary')])
        }
        .width(56)
        .height(56)
        .backgroundColor(gc('transparent'))
        .onClick(() => {
          // 跳转到历史记录页面
          router.pushUrl({ url: 'pages/TransferHistory' });
        })

        // 信息按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(24)
            .fontColor([gc('text_secondary')])
        }
        .width(56)
        .height(56)
        .backgroundColor(gc('transparent'))
        .onClick(() => {
          this.showAdvancedInfo = !this.showAdvancedInfo;
        })
      }
      .margin({ top: 20, right: 16 })
      .zIndex(1)

      Scroll() {
        Column() {
          // Logo & 雷达部分
          Column() {
            Stack() {
              // 背景扩散环 (雷达波纹)
              if (this.isServerRunning) {
                ForEach([0, 1, 2], (i: number) => {
                  Circle()
                    .width(140 + ((this.animationAngle + i * 120) % 360) / 360 * 200)
                    .height(140 + ((this.animationAngle + i * 120) % 360) / 360 * 200)
                    .fill(Color.Transparent)
                    .stroke(gc('accent'))
                    .strokeWidth(2)
                    .opacity(Math.max(0, 1 - ((this.animationAngle + i * 120) % 360) / 360))
                })
              }

              Image($r('app.media.app_icon'))
                .width(140)
                .height(140)
                .borderRadius(28)
                .shadow({ radius: 20, color: '#40000000', offsetY: 10 })
            }
            .width(340)
            .height(340)
            .alignContent(Alignment.Center)
            .margin({ top: 40, bottom: 20 })
            
            Text(this.aliasName)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
            
            Toggle({ type: ToggleType.Switch, isOn: this.isServerRunning })
              .margin({ top: 10 })
              .onChange((isOn: boolean) => {
                this.isServerRunning = isOn;
              })
            
            // 显示 IP 地址
            if (this.isServerRunning && this.localIps.length > 0) {
              Column() {
                ForEach(this.localIps, (ip: string) => {
                  Text(ip)
                    .fontSize(14)
                    .fontColor(gc('text_secondary'))
                })
              }
              .margin({ top: 8 })
            } else if (!this.isServerRunning) {
              Text(t('offline'))
                .fontSize(16)
                .fontColor(gc('text_tertiary'))
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 待接收请求
          if (this.pendingRequests.size > 0) {
            Column() {
              Text(t('pending_files'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary'))
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
                    Button(t('reject'))
                      .fontSize(14)
                      .fontColor(gc('error'))
                      .backgroundColor(gc('error_bg'))
                      .borderRadius(8)
                      .layoutWeight(1)
                      .onClick(() => this.rejectRequest(entry[0]))

                    Blank().width(16)

                    Button(t('accept'))
                      .fontSize(14)
                      .fontColor(gc('success'))
                      .backgroundColor(gc('success_bg'))
                      .borderRadius(8)
                      .layoutWeight(1)
                      .onClick(() => this.acceptRequest(entry[0]))
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(gc('bg_secondary'))
                .borderRadius(12)
                .margin({ bottom: 12 })
              }, (entry: [string, FileRequestInfo]) => entry[0])
            }
            .width('90%')
            .margin({ top: 20 })
          }

          // 传输进度
          if (this.receiveTasks.length > 0) {
            Column() {
              Text(t('in_progress'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary'))
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
            .width('90%')
            .margin({ top: 20 })
          }

          // 高级信息卡片
          if (this.showAdvancedInfo) {
            Column() {
              Row() {
                Text(t('device_alias'))
                  .width('30%')
                  .fontColor(gc('text_secondary'))
                Text(this.aliasName)
                  .fontColor(gc('text_primary'))
              }
              .width('100%')
              .margin({ bottom: 10 })
              
              Row() {
                Text(t('device_ip'))
                  .width('30%')
                  .fontColor(gc('text_secondary'))
                Column() {
                  ForEach(this.localIps, (ip: string) => {
                    Text(ip).fontColor(gc('text_primary'))
                  })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .margin({ bottom: 10 })
              
              Row() {
                Text(t('device_port'))
                  .width('30%')
                  .fontColor(gc('text_secondary'))
                Text(this.port.toString())
                  .fontColor(gc('text_primary'))
              }
              .width('100%')
            }
            .width('90%')
            .padding(20)
            .backgroundColor(gc('bg_secondary'))
            .borderRadius(16)
            .margin({ top: 20 })
            .shadow({ radius: 10, color: '#1A000000' })
          }

          // 快速保存
          Column() {
            Text(t('quick_save'))
              .fontSize(14)
              .fontColor(gc('text_secondary'))
              .margin({ bottom: 10 })
            
            Row() {
              this.QuickSaveButton(t('quick_save_off'), 0)
              this.QuickSaveButton(t('quick_save_fav'), 1)
              this.QuickSaveButton(t('quick_save_on'), 2)
            }
            .width('100%')
            .height(40)
            .backgroundColor(gc('divider'))
            .borderRadius(20)
            .padding(2)
          }
          .width('80%')
          .margin({ top: 20, bottom: 40 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(gc('bg_primary'))
    }
  }

  @Builder QuickSaveButton(label: string, index: number) {
    Text(label)
      .layoutWeight(1)
      .height('100%')
      .textAlign(TextAlign.Center)
      .fontSize(14)
      .fontColor(this.quickSaveMode === index ? gc('text_primary') : gc('text_secondary'))
      .backgroundColor(this.quickSaveMode === index ? gc('bg_secondary') : gc('transparent'))
      .borderRadius(18)
      .onClick(() => {
        this.quickSaveMode = index;
        this.settingsService.setQuickSaveMode(index);
      })
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}

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
  @StorageLink('appPinCode') pinCode: string = '';
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
  @State pendingRequests: Map<string, FileRequestInfo> = new Map();
  @State activeReceiveTask: TransferTask | null = null;
  
  private settingsService: SettingsService = SettingsService.getInstance();
  private fileRequestCallback = (requestJson: string) => {
    this.handleFileRequest(requestJson);
  };

  private taskUpdateListener = (tasks: TransferTask[]) => {
    this.updateActiveReceiveTask();
  };

  private updateActiveReceiveTask() {
    const allTasks = fileTransferManager.getAllTasks();
    const receiveTasks = allTasks.filter(t => 
      t.direction === TransferDirection.Receive && 
      (t.state === TransferState.Pending || t.state === TransferState.InProgress)
    );
    if (receiveTasks.length > 0) {
      // 取出最新的那一条（末尾）
      this.activeReceiveTask = receiveTasks[receiveTasks.length - 1];
    } else {
      this.activeReceiveTask = null;
    }
  }

  aboutToAppear() {
    // 注册文件请求回调
    localSendService.registerFileCallback(this.fileRequestCallback);
    this.updateActiveReceiveTask();
    fileTransferManager.onUpdate(this.taskUpdateListener);
  }

  aboutToDisappear() {
    localSendService.unregisterFileCallback(this.fileRequestCallback);
    fileTransferManager.offUpdate(this.taskUpdateListener);
  }

  private async handleFileRequest(requestJson: string) {
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

      // 检查自动接受
      const settings = await this.settingsService.getSettings();
      const isFav = device.fingerprint ? settings.favorites.includes(device.fingerprint) : false;
      
      // 0: 关, 1: 收藏, 2: 总是
      if (settings.quickSaveMode === 2 || (settings.quickSaveMode === 1 && isFav)) {
        console.info(`[ReceiveTab] Auto-accept enabled. Skip showing request ${request.id} on home screen.`);
        return;
      }

      this.pendingRequests.set(request.id, info);
      this.pendingRequests = new Map(this.pendingRequests);
    } catch (e) {
      console.error('Failed to parse file request:', e);
    }
  }

  private async acceptRequest(requestId: string) {
    const request = this.pendingRequests.get(requestId);
    if (!request) return;

    // 创建接收任务
    const actualDir = fileTransferManager.resolveSavePath(this.saveDir);
    const task = fileTransferManager.createReceiveTask(
      requestId,
      request.device,
      request.files,
      actualDir
    );

    // 注册回调
    fileTransferManager.registerCallback(task.id, {
      onProgress: (task: TransferTask) => {
        // 无需在首页更新
      }
    });

    // 接受请求
    const success = await fileTransferManager.acceptReceive(requestId, actualDir);
    if (success) {
      this.pendingRequests.delete(requestId);
      this.pendingRequests = new Map(this.pendingRequests);
      // promptAction.showToast({ message: t('receive_start', this.languageVersion) });
    } else {
      promptAction.showToast({ message: t('accept_failed', this.languageVersion) });
    }
  }

  private rejectRequest(requestId: string) {
    fileTransferManager.rejectReceive(requestId);
    this.pendingRequests.delete(requestId);
    this.pendingRequests = new Map(this.pendingRequests);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          // Logo & 雷达部分
          Column() {
            Stack() {
              // 背景扩散环 (雷达波纹)
              if (this.isServerRunning) {
                ForEach([0, 1, 2], (i: number) => {
                  Circle()
                    .width(140 + ((this.animationAngle + i * 120) % 360) / 360 * 140)
                    .height(140 + ((this.animationAngle + i * 120) % 360) / 360 * 140)
                    .fill(Color.Transparent)
                    .stroke(gc('accent', this.themeVersion))
                    .strokeWidth(2)
                    .opacity(Math.max(0, 1 - ((this.animationAngle + i * 120) % 360) / 360))
                    .hitTestBehavior(HitTestMode.None)
                })
              }

              Image($r('app.media.app_icon'))
                .width(140)
                .height(140)
                .borderRadius(28)
                .shadow({ radius: 20, color: '#40000000', offsetY: 10 })
            }
            .width(280)
            .height(280)
            .alignContent(Alignment.Center)
            .margin({ top: 60, bottom: 20 })
            .hitTestBehavior(HitTestMode.None)
            
            Text(this.aliasName)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(gc('text_primary', this.themeVersion))
            
            if (this.pinCode) {
              Row() {
                SymbolGlyph($r('sys.symbol.lock_fill'))
                  .fontSize(12)
                  .fontColor([gc('accent', this.themeVersion)])
                  .margin({ right: 4 })
                Text(`PIN: ${this.pinCode}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(gc('accent', this.themeVersion))
              }
              .backgroundColor(gc('accent_bg', this.themeVersion))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(8)
              .margin({ top: 6 })
            }
            
            Toggle({ type: ToggleType.Switch, isOn: this.isServerRunning })
              .margin({ top: 10 })
              .selectedColor(gc('accent', this.themeVersion))
              .onChange((isOn: boolean) => {
                this.isServerRunning = isOn;
              })
            
            // 显示 IP 地址
            if (this.isServerRunning && this.localIps.length > 0) {
              Column() {
                ForEach(this.localIps, (ip: string) => {
                  Text(ip)
                    .fontSize(14)
                    .fontColor(gc('text_secondary', this.themeVersion))
                })
              }
              .margin({ top: 8 })
            } else if (!this.isServerRunning) {
              Text(t('offline', this.languageVersion))
                .fontSize(16)
                .fontColor(gc('text_tertiary', this.themeVersion))
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 待接收请求
          if (this.pendingRequests.size > 0) {
            Column() {
              Text(t('pending_files', this.languageVersion))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary', this.themeVersion))
                .width('100%')
                .margin({ bottom: 12 })

              ForEach(Array.from(this.pendingRequests.entries()), (entry: [string, FileRequestInfo]) => {
                Column() {
                  Row() {
                    Text(entry[1].device.alias)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(gc('text_primary', this.themeVersion))
                    
                    Blank()
                    
                    Text(formatSize(entry[1].totalSize))
                      .fontSize(14)
                      .fontColor(gc('text_secondary', this.themeVersion))
                  }
                  .width('100%')
                  .margin({ bottom: 8 })

                  Text(`${entry[1].files.length} ${t('file_count', this.languageVersion)}`)
                    .fontSize(14)
                    .fontColor(gc('text_secondary', this.themeVersion))
                    .width('100%')
                    .margin({ bottom: 12 })

                  Row() {
                    Button(t('reject', this.languageVersion))
                      .fontSize(14)
                      .fontColor(gc('error', this.themeVersion))
                      .backgroundColor(Color.Transparent)
                      .border({ width: 1, color: gc('error', this.themeVersion) })
                      .borderRadius(12)
                      .layoutWeight(1)
                      .onClick(() => this.rejectRequest(entry[0]))

                    Blank().width(16)

                    Button(t('accept', this.languageVersion))
                      .fontSize(14)
                      .fontColor(Color.White)
                      .backgroundColor(gc('success', this.themeVersion))
                      .borderRadius(12)
                      .layoutWeight(1)
                      .onClick(() => this.acceptRequest(entry[0]))
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(gc('bg_secondary', this.themeVersion))
                .borderRadius(12)
                .margin({ bottom: 12 })
              }, (entry: [string, FileRequestInfo]) => entry[0])
            }
            .width('100%')
            .margin({ top: 20 })
          }



          // 高级信息卡片
          if (this.showAdvancedInfo) {
            Column() {
              Row() {
                Text(t('device_alias', this.languageVersion))
                  .width('30%')
                  .fontColor(gc('text_secondary', this.themeVersion))
                Text(this.aliasName)
                  .fontColor(gc('text_primary', this.themeVersion))
              }
              .width('100%')
              .margin({ bottom: 10 })
              
              Row() {
                Text(t('device_ip', this.languageVersion))
                  .width('30%')
                  .fontColor(gc('text_secondary', this.themeVersion))
                Column() {
                  ForEach(this.localIps, (ip: string) => {
                    Text(ip).fontColor(gc('text_primary', this.themeVersion))
                  })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .margin({ bottom: 10 })
              
              Row() {
                Text(t('device_port', this.languageVersion))
                  .width('30%')
                  .fontColor(gc('text_secondary', this.themeVersion))
                Text(this.port.toString())
                  .fontColor(gc('text_primary', this.themeVersion))
              }
              .width('100%')
            }
            .width('100%')
            .padding(20)
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .margin({ top: 20 })
            .shadow({ radius: 10, color: '#1A000000' })
          }

          // 快速保存
          Column() {
            Text(t('quick_save', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .margin({ bottom: 10 })
            
            Row() {
              QuickSaveButtonComponent({ index: 0, currentMode: $quickSaveMode, languageVersion: this.languageVersion })
              QuickSaveButtonComponent({ index: 1, currentMode: $quickSaveMode, languageVersion: this.languageVersion })
              QuickSaveButtonComponent({ index: 2, currentMode: $quickSaveMode, languageVersion: this.languageVersion })
            }
            .width('100%')
            .height(40)
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .border({ width: 1, color: gc('divider', this.themeVersion) })
            .borderRadius(20)
            .padding(2)
          }
          .width('100%')
          .margin({ top: 20, bottom: 20 })

          // 底部传输状态与历史跳转卡片
          Column() {
            if (this.activeReceiveTask) {
              Text(t('current_receiving', this.languageVersion))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_secondary', this.themeVersion))
                .width('100%')
                .margin({ bottom: 8 })

              TransferProgressCard({
                task: this.activeReceiveTask,
                onCancel: (taskId: string) => {
                  fileTransferManager.cancelTransfer(taskId);
                  this.updateActiveReceiveTask();
                }
              })
            } else {
              Button({ type: ButtonType.Normal }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.clock_fill'))
                    .fontSize(16)
                    .fontColor([gc('accent', this.themeVersion)])
                    .margin({ right: 8 })
                  Text(t('view_history', this.languageVersion))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(gc('accent', this.themeVersion))
                }
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .height(48)
              .backgroundColor(gc('accent_bg', this.themeVersion))
              .borderRadius(12)
              .onClick(() => {
                router.pushUrl({ url: 'pages/TransferHistory' });
              })
            }
          }
          .width('100%')
          .margin({ top: 10, bottom: 40 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(gc('bg_primary', this.themeVersion))
      .align(Alignment.Top)
      .key(`receive_tab_scroll_${this.themeRefreshKey}`)

      // 右上角按钮 (置于 Scroll 之后以确立最高的层叠顺序)
      Row() {
        // 历史记录按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(24)
            .fontColor([gc('text_secondary', this.themeVersion)])
        }
        .width(56)
        .height(56)
        .backgroundColor(gc('transparent', this.themeVersion))
        .onClick(() => {
          // 跳转到历史记录页面
          router.pushUrl({ url: 'pages/TransferHistory' });
        })

        // 信息按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(24)
            .fontColor([gc('text_secondary', this.themeVersion)])
        }
        .width(56)
        .height(56)
        .backgroundColor(gc('transparent', this.themeVersion))
        .onClick(() => {
          this.showAdvancedInfo = !this.showAdvancedInfo;
        })
      }
      .margin({ top: 20, right: 16 })
      .zIndex(10)
    }
    .width('100%')
    .height('100%')
  }

}

@Component
struct QuickSaveButtonComponent {
  @Prop index: number;
  @Link currentMode: number;
  @Prop languageVersion: number;
  @StorageProp('themeVersion') themeVersion: number = 0;
  private settingsService = SettingsService.getInstance();

  build() {
    Text(this.index === 0 ? t('quick_save_off', this.languageVersion) :
         this.index === 1 ? t('quick_save_fav', this.languageVersion) :
         t('quick_save_on', this.languageVersion))
      .layoutWeight(1)
      .height('100%')
      .textAlign(TextAlign.Center)
      .fontSize(14)
      .fontWeight(this.currentMode === this.index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentMode === this.index ? Color.White : gc('text_secondary', this.themeVersion))
      .backgroundColor(this.currentMode === this.index ? gc('accent', this.themeVersion) : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        this.currentMode = this.index;
        this.settingsService.setQuickSaveMode(this.index);
      })
  }
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

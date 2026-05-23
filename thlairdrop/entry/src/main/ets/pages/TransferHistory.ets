import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import fileUri from '@ohos.file.fileuri';
import common from '@ohos.app.ability.common';
import wantConstant from '@ohos.app.ability.wantConstant';
import { Want } from '@kit.AbilityKit';
import { historyService, HistoryRecord } from '../services/HistoryService';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import { PageHeader } from '../components/PageHeader';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { TransferProgressCard } from '../components/TransferProgressCard';

@Entry
@Component
struct TransferHistory {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @Watch('onTabChanged') @State currentTab: number = 0; // 0: 接收, 1: 发送
  @State historyRecords: HistoryRecord[] = [];
  @State activeTasks: TransferTask[] = [];
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  
  get bottomPadding(): number {
    const navBarVp = px2vp(this.navigationBarHeight);
    return navBarVp > 0 ? Math.max(navBarVp, 28) : 28;
  }

  onRefreshTriggered() {
    this.refreshKey++;
  }

  onTabChanged() {
    this.updateActiveTasks();
  }

  private taskUpdateListener = (tasks: TransferTask[]) => {
    this.updateActiveTasks();
  };

  private updateActiveTasks() {
    const allTasks = fileTransferManager.getAllTasks();
    this.activeTasks = allTasks.filter(t => 
      t.direction === (this.currentTab === 0 ? TransferDirection.Receive : TransferDirection.Send) && 
      (t.state === TransferState.Pending || t.state === TransferState.InProgress)
    );
  }

  async aboutToAppear() {
    await this.loadHistory();
    this.updateActiveTasks();
    fileTransferManager.onUpdate(this.taskUpdateListener);
  }

  aboutToDisappear() {
    fileTransferManager.offUpdate(this.taskUpdateListener);
  }

  private async loadHistory() {
    this.historyRecords = await historyService.getAllRecords();
  }

  private async clearHistory() {
    await historyService.clearAll();
    await this.loadHistory();
    promptAction.showToast({ message: t('clear', this.languageVersion) });
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    return `${y}-${m}-${d} ${hh}:${mm}`;
  }

  build() {
    Stack() {
      // 1. 背景色容器 (铺满屏幕)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 实际内容容器 (安全区内)
      Column() {
        PageHeader({
          title: t('history_title', this.languageVersion),
          centerTitle: true,
          showActionButton: true,
          actionIcon: $r('sys.symbol.trash'),
          onActionClick: (): void => { this.clearHistory(); },
          themeVersion: this.themeVersion
        })

        // 分段切换器
        Row() {
          Column() {
            Text(t('tab_receive', this.languageVersion))
              .fontSize(16)
              .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.currentTab === 0 ? gc('accent', this.themeVersion) : gc('text_secondary', this.themeVersion))
            
            if (this.currentTab === 0) {
              Divider()
                .strokeWidth(3)
                .color(gc('accent', this.themeVersion))
                .width(40)
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .onClick(() => { this.currentTab = 0; })

          Column() {
            Text(t('tab_send', this.languageVersion))
              .fontSize(16)
              .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.currentTab === 1 ? gc('accent', this.themeVersion) : gc('text_secondary', this.themeVersion))
            
            if (this.currentTab === 1) {
              Divider()
                .strokeWidth(3)
                .color(gc('accent', this.themeVersion))
                .width(40)
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .onClick(() => { this.currentTab = 1; })
        }
        .width('100%')
        .height(50)
        .backgroundColor(gc('bg_secondary', this.themeVersion))
        .padding({ top: 10 })

        // 历史列表
        if (this.activeTasks.length > 0 || this.getFilteredHistory().length > 0) {
          List({ space: 12 }) {
            // 正在进行的任务
            ForEach(this.activeTasks, (task: TransferTask) => {
              ListItem() {
                TransferProgressCard({
                  task: task,
                  onCancel: (taskId: string) => {
                    fileTransferManager.cancelTransfer(taskId);
                    this.updateActiveTasks();
                  }
                })
              }
            }, (task: TransferTask) => task.id)

            ForEach(this.getFilteredHistory(), (item: HistoryRecord) => {
              ListItem() {
                this.HistoryItem(item)
              }
            }, (item: HistoryRecord) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding(16)
          .edgeEffect(EdgeEffect.Spring)
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(64)
              .fontColor([gc('divider', this.themeVersion)])
            Text(t('empty_history', this.languageVersion))
              .fontSize(16)
              .fontColor(gc('text_tertiary', this.themeVersion))
              .margin({ top: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.bottomPadding })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder HistoryItem(item: HistoryRecord) {
    Row() {
      // 图标
      Column() {
        SymbolGlyph(item.direction === 'receive' ? $r('sys.symbol.arrow_down_circle') : $r('sys.symbol.paperplane'))
          .fontSize(28)
          .fontColor([item.direction === 'receive' ? gc('success', this.themeVersion) : gc('accent', this.themeVersion)])
      }
      .width(50)
      .height(50)
      .borderRadius(25)
      .backgroundColor(item.direction === 'receive' ? gc('success_bg', this.themeVersion) : gc('accent_bg', this.themeVersion))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      // 详情
      Column() {
        Text(item.fileName || 'Unknown')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(gc('text_primary', this.themeVersion))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        Row() {
          Text(item.deviceName)
            .fontSize(12)
            .fontColor(gc('text_secondary', this.themeVersion))
          
          Text(' • ')
            .fontSize(12)
            .fontColor(gc('text_tertiary', this.themeVersion))
          
          Text(this.formatSize(item.size))
            .fontSize(12)
            .fontColor(gc('text_secondary', this.themeVersion))
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 状态
      Column() {
        Text(this.formatTime(item.time))
          .fontSize(11)
          .fontColor(gc('text_secondary', this.themeVersion))
          .margin({ bottom: 4 })
        
        Text(item.status === 'completed' ? t('completed', this.languageVersion) : t('failed', this.languageVersion))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status === 'completed' ? gc('success', this.themeVersion) : gc('error', this.themeVersion))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(item.status === 'completed' ? gc('success_bg', this.themeVersion) : gc('error_bg', this.themeVersion))
          .borderRadius(4)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(gc('bg_secondary', this.themeVersion))
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
    .onClick(() => {
      this.handleHistoryItemClick(item);
    })
  }

  private getFilteredHistory(): HistoryRecord[] {
    return this.historyRecords.filter(t => t.direction === (this.currentTab === 0 ? 'receive' : 'send'));
  }

  private handleHistoryItemClick(item: HistoryRecord) {
    if (item.status === 'completed' && item.filePath) {
      let exists = false;
      try {
        exists = fs.accessSync(item.filePath);
      } catch (e) {
        exists = false;
      }

      if (exists) {
        let buttons: [promptAction.Button, promptAction.Button, promptAction.Button] = [
          { text: '打开文件', color: '#3B82F6' },
          { text: '另存为/导出', color: '#10B981' },
          { text: '删除记录', color: '#EF4444' }
        ];

        promptAction.showActionMenu({
          title: item.fileName,
          buttons: buttons
        }).then(data => {
          if (data.index === 0) {
            this.openFile(item);
          } else if (data.index === 1) {
            this.exportFile(item);
          } else if (data.index === 2) {
            this.deleteRecord(item);
          }
        }).catch((err: Error) => {
          console.error('[History] Action menu error:', err);
        });
        return;
      }
    }

    // 默认情况：只有删除记录按钮
    let buttons: [promptAction.Button] = [
      { text: '删除记录', color: '#EF4444' }
    ];

    promptAction.showActionMenu({
      title: item.fileName,
      buttons: buttons
    }).then(data => {
      if (data.index === 0) {
        this.deleteRecord(item);
      }
    }).catch((err: Error) => {
      console.error('[History] Action menu error:', err);
    });
  }

  private async openFile(item: HistoryRecord) {
    if (!item.filePath) {
      promptAction.showToast({ message: '文件路径不存在' });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const uri = fileUri.getUriFromPath(item.filePath);
      const mimeType = this.getMimeType(item.fileName);

      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: uri,
        type: mimeType,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };

      await context.startAbility(want);
      console.info(`[History] Opened file: ${item.filePath}`);
    } catch (err) {
      promptAction.showToast({ message: '未找到支持打开该文件的应用' });
      console.error('[History] Failed to open file:', err);
    }
  }

  private async exportFile(item: HistoryRecord) {
    if (!item.filePath) {
      promptAction.showToast({ message: '文件路径不存在' });
      return;
    }

    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [item.fileName];
      
      const documentViewPicker = new picker.DocumentViewPicker();
      const saveResult = await documentViewPicker.save(documentSaveOptions);
      
      if (saveResult && saveResult.length > 0) {
        const uri = saveResult[0];
        await fs.copyFile(item.filePath, uri);
        promptAction.showToast({ message: '文件已成功导出' });
      }
    } catch (err) {
      promptAction.showToast({ message: `导出失败: ${err.message || err}` });
      console.error('[History] Failed to export file:', err);
    }
  }

  private async deleteRecord(item: HistoryRecord) {
    await historyService.deleteRecord(item.id);
    await this.loadHistory();
    promptAction.showToast({ message: '记录已删除' });
  }

  private getMimeType(fileName: string): string {
    const dot = fileName.lastIndexOf('.');
    if (dot === -1) return '*/*';
    const ext = fileName.substring(dot + 1).toLowerCase();
    const mimes: Record<string, string> = {
      'txt': 'text/plain',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'json': 'application/json',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'pdf': 'application/pdf',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'zip': 'application/zip',
      'apk': 'application/vnd.android.package-archive'
    };
    return mimes[ext] || '*/*';
  }
}

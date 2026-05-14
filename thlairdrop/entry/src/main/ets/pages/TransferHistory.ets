import router from '@ohos.router';
import fs from '@ohos.file.fs';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

// 历史记录项
interface HistoryItem {
  id: string;
  fileName: string;
  size: number;
  time: string;
  direction: 'send' | 'receive';
  deviceName: string;
  status: 'completed' | 'failed';
  filePath?: string;
}

@Entry
@Component
struct TransferHistory {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @State currentTab: number = 0; // 0: 接收, 1: 发送
  @State receiveHistory: HistoryItem[] = [];
  @State sendHistory: HistoryItem[] = [];
  
  aboutToAppear() {
    this.loadHistory();
  }
  
  private loadHistory() {
    // 从传输管理器获取历史记录
    const allTasks = fileTransferManager.getAllTasks();
    
    this.receiveHistory = allTasks
      .filter(t => t.direction === TransferDirection.Receive)
      .map(t => this.taskToHistory(t));
    
    this.sendHistory = allTasks
      .filter(t => t.direction === TransferDirection.Send)
      .map(t => this.taskToHistory(t));
  }
  
  private taskToHistory(task: TransferTask): HistoryItem {
    return {
      id: task.id,
      fileName: task.files.length > 0 ? task.files[0].fileName : 'Unknown',
      size: task.totalSize,
      time: this.formatTime(task.startTime),
      direction: task.direction === TransferDirection.Receive ? 'receive' : 'send',
      deviceName: task.device ? task.device.alias : 'Unknown',
      status: task.state === TransferState.Completed ? 'completed' : 'failed',
      filePath: task.direction === TransferDirection.Receive && task.saveDir 
        ? `${task.saveDir}/${task.files.length > 0 ? task.files[0].fileName : ''}`
        : (task.files.length > 0 ? task.files[0].filePath : undefined)
    };
  }
  
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }
  
  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  
  // 打开文件
  private openFile(item: HistoryItem) {
    if (!item.filePath) {
      return;
    }
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let want: Want = {
        action: 'ohos.want.action.viewData',
        uri: `file://${item.filePath}`
      };
      context.startAbility(want).then(() => {
        console.info('Succeeded in starting ability for file view');
      }).catch((err: Error) => {
        console.error('Failed to start ability for file view:', err);
      });
    } catch (e) {
      console.error('Failed to open file:', e);
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        // 返回按钮
        Button({ type: ButtonType.Circle }) {
          Path()
            .width(24)
            .height(24)
            .commands('M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z')
            .fill(gc('text_primary'))
        }
        .width(44)
        .height(44)
        .backgroundColor(gc('transparent'))
        .onClick(() => {
          router.back();
        })
        
        Text(t('history_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(gc('text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        // 占位
        Blank().width(44)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      
      // Tab 切换
      Row() {
        Text(t('tab_receive'))
          .fontSize(16)
          .fontColor(this.currentTab === 0 ? gc('accent') : gc('text_secondary'))
          .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.currentTab = 0; })
        
        Divider()
          .vertical(true)
          .height(20)
          .color(gc('divider'))
        
        Text(t('tab_send'))
          .fontSize(16)
          .fontColor(this.currentTab === 1 ? gc('accent') : gc('text_secondary'))
          .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.currentTab = 1; })
      }
      .width('90%')
      .height(48)
      .backgroundColor(gc('bg_secondary'))
      .borderRadius(24)
      .margin({ top: 16 })
      
      // 列表
      if (this.currentTab === 0) {
        this.HistoryList(this.receiveHistory)
      } else {
        this.HistoryList(this.sendHistory)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary'))
  }
  
  @Builder HistoryList(items: HistoryItem[]) {
    if (items.length === 0) {
      Column() {
        // 空状态图标
        Path()
          .width(64)
          .height(64)
          .commands('M20 6h-8l-2-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 12H4V8h16v10z')
          .fill(gc('divider'))
        
        Text(t('empty_history'))
          .fontSize(16)
          .fontColor(gc('text_tertiary'))
          .margin({ top: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(items, (item: HistoryItem) => {
          ListItem() {
            Row() {
              // 文件图标
              Column() {
                Path()
                  .width(36)
                  .height(36)
                  .commands('M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z')
                  .fill(item.direction === 'receive' ? gc('success') : gc('accent'))
              }
              .width(56)
              .height(56)
              .borderRadius(12)
              .backgroundColor(item.direction === 'receive' ? gc('success_bg') : gc('accent_bg'))
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })
              
              Column() {
                Text(item.fileName)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(gc('text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                
                Row() {
                  Text(item.deviceName)
                    .fontSize(12)
                    .fontColor(gc('text_secondary'))
                  
                  Text(' • ')
                    .fontSize(12)
                    .fontColor(gc('text_tertiary'))
                  
                  Text(this.formatSize(item.size))
                    .fontSize(12)
                    .fontColor(gc('text_secondary'))
                }
                .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              
              Column() {
                Text(item.time)
                  .fontSize(12)
                  .fontColor(gc('text_secondary'))
                
                Text(item.status === 'completed' ? t('completed') : t('failed'))
                  .fontSize(12)
                  .fontColor(item.status === 'completed' ? gc('success') : gc('error'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(gc('bg_secondary'))
            .borderRadius(12)
            .onClick(() => {
              this.openFile(item);
            })
          }
        })
      }
      .width('90%')
      .layoutWeight(1)
      .margin({ top: 16 })
      .padding({ bottom: 20 })
    }
  }
}

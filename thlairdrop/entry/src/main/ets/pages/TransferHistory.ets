import router from '@ohos.router';
import fs from '@ohos.file.fs';
import { fileTransferManager, TransferState, TransferDirection } from '../service/FileTransferManager';
import { historyService, HistoryRecord } from '../services/HistoryService';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct TransferHistory {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @State currentTab: number = 0; // 0: 接收, 1: 发送
  
  onRefreshTriggered() {
    this.refreshKey++;
  }
  @State receiveHistory: HistoryRecord[] = [];
  @State sendHistory: HistoryRecord[] = [];
  @State isLoading: boolean = true;
  
  aboutToAppear() {
    this.loadHistory();
  }
  
  private async loadHistory() {
    this.isLoading = true;
    // 从持久化服务获取历史记录
    const allRecords = await historyService.getAllRecords();
    
    this.receiveHistory = allRecords.filter(r => r.direction === 'receive');
    this.sendHistory = allRecords.filter(r => r.direction === 'send');
    this.isLoading = false;
  }
  
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    
    // 如果是今天的记录，只显示时间
    if (date.toDateString() === now.toDateString()) {
      return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
    }
    
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }
  
  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  
  // 打开文件
  private openFile(item: HistoryRecord) {
    if (!item.filePath || item.status !== 'completed') {
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
        promptAction.showToast({ message: '无法打开文件，请检查是否安装了相关应用' });
      });
    } catch (e) {
      console.error('Failed to open file:', e);
    }
  }

  private async clearHistory() {
    await historyService.clearAll();
    this.loadHistory();
    promptAction.showToast({ message: '历史记录已清除' });
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        // 返回按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([gc('text_primary')])
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
        
        // 清除按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([gc('text_secondary')])
        }
        .width(44)
        .height(44)
        .backgroundColor(gc('transparent'))
        .onClick(() => {
          this.clearHistory();
        })
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
          .height('100%')
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
          .height('100%')
          .onClick(() => { this.currentTab = 1; })
      }
      .width('90%')
      .height(48)
      .backgroundColor(gc('bg_secondary'))
      .borderRadius(24)
      .margin({ top: 16 })
      .padding(4)
      
      // 列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .color(gc('accent'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.currentTab === 0) {
          this.HistoryList(this.receiveHistory)
        } else {
          this.HistoryList(this.sendHistory)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary'))
    .key(`history_column_${this.refreshKey}`)
  }
  
  @Builder HistoryList(items: HistoryRecord[]) {
    if (items.length === 0) {
      Column() {
        // 空状态图标
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(72)
          .fontColor([gc('divider')])
        
        Text(t('empty_history'))
          .fontSize(16)
          .fontColor(gc('text_tertiary'))
          .margin({ top: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(items, (item: HistoryRecord) => {
          ListItem() {
            Row() {
              // 文件图标
              Column() {
                SymbolGlyph($r('sys.symbol.doc'))
                  .fontSize(32)
                  .fontColor([item.direction === 'receive' ? gc('success') : gc('accent')])
              }
              .width(52)
              .height(52)
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
                Text(this.formatTime(item.time))
                  .fontSize(11)
                  .fontColor(gc('text_secondary'))
                
                Text(item.status === 'completed' ? t('completed') : t('failed'))
                  .fontSize(11)
                  .fontColor(item.status === 'completed' ? gc('success') : gc('error'))
                  .margin({ top: 4 })
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(item.status === 'completed' ? gc('success_bg') : gc('error_bg'))
                  .borderRadius(4)
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(gc('bg_secondary'))
            .borderRadius(16)
            .onClick(() => {
              this.openFile(item);
            })
          }
        }, (item: HistoryRecord) => item.id)
      }
      .width('95%')
      .layoutWeight(1)
      .margin({ top: 16 })
      .padding({ bottom: 20 })
      .scrollBar(BarState.Off)
    }
  }
}


import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { historyService, HistoryRecord } from '../services/HistoryService';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import { PageHeader } from '../components/PageHeader';

@Entry
@Component
struct TransferHistory {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @State currentTab: number = 0; // 0: 接收, 1: 发送
  @State historyRecords: HistoryRecord[] = [];

  onRefreshTriggered() {
    this.refreshKey++;
  }

  async aboutToAppear() {
    await this.loadHistory();
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
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
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
        if (this.getFilteredHistory().length > 0) {
          List({ space: 12 }) {
            ForEach(this.getFilteredHistory(), (item: HistoryRecord) => {
              ListItem() {
                this.HistoryItem(item)
              }
            })
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
  }

  private getFilteredHistory(): HistoryRecord[] {
    return this.historyRecords.filter(t => t.direction === (this.currentTab === 0 ? 'receive' : 'send'));
  }
}

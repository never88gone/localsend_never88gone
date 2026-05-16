/**
 * 传输进度组件
 * 
 * 显示文件传输进度、状态和控制按钮
 */

import { TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { FileInfo } from '../service/LocalSendService';
import promptAction from '@ohos.promptAction';
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

@Component
export struct TransferProgressCard {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  @Prop task: TransferTask;
  @State isExpanded: boolean = false;
  onCancel?: (taskId: string) => void;
  onRetry?: (taskId: string) => void;

  build() {
    Column() {
      // 标题行
      Row() {
        // 方向图标
        if (this.task.direction === TransferDirection.Send) {
          SymbolGlyph($r('sys.symbol.paperplane_fill'))
            .fontSize(20)
            .fontColor([gc('accent')])
        } else {
          SymbolGlyph($r('sys.symbol.arrow_down_circle'))
            .fontSize(20)
            .fontColor([gc('success')])
        }

        Text(this.task.direction === TransferDirection.Send ? t('tab_send') : t('tab_receive'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary'))
          .margin({ left: 8 })

        Blank()

        // 状态标签
        this.StateLabel()
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 设备信息
      Row() {
        SymbolGlyph($r('sys.symbol.display'))
          .fontSize(16)
          .fontColor([gc('text_secondary')])
          .margin({ right: 6 })

        Text(this.task.device.alias || 'Unknown')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(gc('text_primary'))
        
        Text(`(${this.task.device.ip})`)
          .fontSize(12)
          .fontColor(gc('text_tertiary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 文件数量和大小 (点击可展开)
      Row() {
        Text(`${this.task.files.length} ${t('file')}`)
          .fontSize(14)
          .fontColor(gc('text_secondary'))
        
        Text(' • ')
          .fontColor(gc('text_tertiary'))
        
        Text(this.formatSize(this.task.totalSize))
          .fontSize(14)
          .fontColor(gc('text_secondary'))

        Blank()

        if (this.task.files.length > 0) {
          SymbolGlyph(this.isExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([gc('text_tertiary')])
        }
      }
      .width('100%')
      .margin({ bottom: 12 })
      .onClick(() => {
        if (this.task.files.length > 0) {
          this.isExpanded = !this.isExpanded;
        }
      })

      // 展开的文件列表
      if (this.isExpanded && this.task.files.length > 0) {
        Column() {
          ForEach(this.task.files, (file: FileInfo) => {
            Row() {
              SymbolGlyph($r('sys.symbol.doc'))
                .fontSize(14)
                .fontColor([gc('text_tertiary')])
                .margin({ right: 8 })
              
              Text(file.fileName)
                .fontSize(13)
                .fontColor(gc('text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              
              Text(this.formatSize(file.size))
                .fontSize(12)
                .fontColor(gc('text_tertiary'))
            }
            .width('100%')
            .margin({ bottom: 6 })
          })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8, bottom: 4 })
        .margin({ bottom: 12 })
        .backgroundColor(gc('bg_primary'))
        .borderRadius(8)
      }

      // 进度条 (高级渐变样式)
      if (this.task.state === TransferState.InProgress || 
          this.task.state === TransferState.Pending) {
        Column() {
          Stack({ alignContent: Alignment.Start }) {
            // 背景轨道
            Rect()
              .width('100%')
              .height(10)
              .fill(gc('accent_bg'))
              .borderRadius(5)
            
            // 进度填充 (渐变效果)
            Rect()
              .width(`${this.task.progress}%`)
              .height(10)
              .fill(gc('accent'))
              .borderRadius(5)
              .animation({ duration: 300, curve: Curve.Smooth })
              .shadow({ radius: 4, color: '#40000000', offsetY: 2 })
          }
          .width('100%')
          
          Row() {
            Text(`${this.task.progress.toFixed(0)}%`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(gc('accent'))
            
            Blank()
            
            Text(`${this.formatSize(this.task.transferredSize)} / ${this.formatSize(this.task.totalSize)}`)
              .fontSize(12)
              .fontColor(gc('text_tertiary'))
          }
          .width('100%')
          .margin({ top: 6 })
        }
        .width('100%')
        .margin({ bottom: 16 })
      }

      // 错误或取消信息
      if (this.task.state === TransferState.Failed) {
        Row() {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize(16)
            .fontColor([gc('error')])
          
          Text(this.task.errorMessage || t('failed'))
            .fontSize(12)
            .fontColor(gc('error'))
            .margin({ left: 6 })
        }
        .width('100%')
        .margin({ bottom: 12 })
        .padding(8)
        .backgroundColor(gc('error_bg'))
        .borderRadius(6)
      }

      // 操作按钮
      Row() {
        if (this.task.state === TransferState.InProgress || this.task.state === TransferState.Pending) {
          Button(t('cancel'))
            .fontSize(13)
            .height(32)
            .fontColor(gc('error'))
            .backgroundColor(gc('transparent'))
            .border({ width: 1, color: gc('error') })
            .borderRadius(16)
            .onClick(() => {
              this.onCancel?.(this.task.id);
            })
        } else if (this.task.state === TransferState.Failed) {
          Button(t('retry'))
            .fontSize(13)
            .height(32)
            .fontColor(gc('accent'))
            .backgroundColor(gc('accent_bg'))
            .borderRadius(16)
            .onClick(() => {
              this.onRetry?.(this.task.id);
            })
        } else if (this.task.state === TransferState.Completed) {
          Button(t('view'))
            .fontSize(13)
            .height(32)
            .fontColor(gc('success'))
            .backgroundColor(gc('success_bg'))
            .borderRadius(16)
            .onClick(() => {
              promptAction.showToast({ message: '文件已保存到相册或下载目录' });
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(16)
    .shadow({ radius: 10, color: '#15000000', offsetY: 4 })
    .key(`transfer_card_${this.refreshKey}`)
  }

  @Builder StateLabel() {
    Row() {
      if (this.task.state === TransferState.Pending) {
        Text(t('waiting'))
          .fontSize(11)
          .fontColor(gc('warning'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(gc('warning_bg'))
          .borderRadius(10)
          .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.8, y: 0.8 } })
      } else if (this.task.state === TransferState.InProgress) {
        Text(t('in_progress'))
          .fontSize(11)
          .fontColor(gc('accent'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(gc('accent_bg'))
          .borderRadius(10)
      } else if (this.task.state === TransferState.Completed) {
        Text(t('completed'))
          .fontSize(11)
          .fontColor(gc('success'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(gc('success_bg'))
          .borderRadius(10)
          .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.8, y: 0.8 } })
      } else if (this.task.state === TransferState.Failed) {
        Text(t('failed'))
          .fontSize(11)
          .fontColor(gc('error'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(gc('error_bg'))
          .borderRadius(10)
          .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.8, y: 0.8 } })
      } else if (this.task.state === TransferState.Cancelled) {
        Text(t('cancelled'))
          .fontSize(11)
          .fontColor(gc('text_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(gc('divider'))
          .borderRadius(10)
          .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.8, y: 0.8 } })
      }
    }
    .animation({ duration: 300, curve: Curve.EaseOut })
  }

  private getProgressColor(): ResourceColor {
    if (this.task.state === TransferState.Failed) {
      return gc('error');
    }
    return gc('accent');
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}

/**
 * 传输列表组件
 */
@Component
export struct TransferList {
  @Link tasks: TransferTask[];
  onCancel?: (taskId: string) => void;
  onRetry?: (taskId: string) => void;

  build() {
    Column() {
      if (this.tasks.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.inbox'))
            .fontSize(48)
            .fontColor(['#CCCCCC'])
          
          Text('暂无传输任务')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 12 })
        }
        .width('100%')
        .height(150)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.tasks, (task: TransferTask) => {
            ListItem() {
              TransferProgressCard({
                task: task,
                onCancel: this.onCancel,
                onRetry: this.onRetry
              })
            }
          }, (task: TransferTask) => task.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
  }
}

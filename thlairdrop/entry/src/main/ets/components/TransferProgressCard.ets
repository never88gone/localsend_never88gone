/**
 * 传输进度组件
 * 
 * 显示文件传输进度、状态和控制按钮
 */

import { TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import promptAction from '@ohos.promptAction';
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

@Component
export struct TransferProgressCard {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Prop task: TransferTask;
  onCancel?: (taskId: string) => void;
  onRetry?: (taskId: string) => void;

  build() {
    Column() {
      // 标题行
      Row() {
        // 方向图标
        if (this.task.direction === TransferDirection.Send) {
          Path()
            .width(20)
            .height(20)
            .commands('M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z')
            .fill(gc('accent'))
        } else {
          Path()
            .width(20)
            .height(20)
            .commands('M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z')
            .fill(gc('success'))
        }

        Text(this.task.direction === TransferDirection.Send ? t('tab_send') : t('tab_receive'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
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
        Text(this.task.device.alias || 'Unknown')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(gc('text_primary'))
        
        Text(`(${this.task.device.ip})`)
          .fontSize(12)
          .fontColor(gc('text_secondary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 文件数量和大小
      Row() {
        Text(`${this.task.files.length} ${t('file')}`)
          .fontSize(14)
          .fontColor(gc('text_secondary'))
        
        Text(' • ')
          .fontColor(gc('text_tertiary'))
        
        Text(this.formatSize(this.task.totalSize))
          .fontSize(14)
          .fontColor(gc('text_secondary'))
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 进度条
      if (this.task.state === TransferState.InProgress || 
          this.task.state === TransferState.Pending) {
        Column() {
          Progress({ value: this.task.progress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(this.getProgressColor())
          
          Row() {
            Text(`${this.task.progress.toFixed(1)}%`)
              .fontSize(12)
              .fontColor(gc('text_secondary'))
            
            Blank()
            
            Text(`${this.formatSize(this.task.transferredSize)} / ${this.formatSize(this.task.totalSize)}`)
              .fontSize(12)
              .fontColor(gc('text_secondary'))
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('100%')
        .margin({ bottom: 12 })
      }

      // 错误信息
      if (this.task.state === TransferState.Failed) {
        Row() {
          Path()
            .width(16)
            .height(16)
            .commands('M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z')
            .fill(gc('error'))
          
          Text(t('failed'))
            .fontSize(12)
            .fontColor(gc('error'))
            .margin({ left: 4 })
        }
        .width('100%')
        .margin({ bottom: 12 })
      }

      // 操作按钮
      Row() {
        if (this.task.state === TransferState.InProgress) {
          Button(t('cancel'))
            .fontSize(14)
            .fontColor(gc('error'))
            .backgroundColor(gc('error_bg'))
            .borderRadius(8)
            .onClick(() => {
              this.onCancel?.(this.task.id);
            })
        } else if (this.task.state === TransferState.Failed) {
          Button(t('retry'))
            .fontSize(14)
            .fontColor(gc('accent'))
            .backgroundColor(gc('accent_bg'))
            .borderRadius(8)
            .onClick(() => {
              this.onRetry?.(this.task.id);
            })
        } else if (this.task.state === TransferState.Completed) {
          Button(t('view'))
            .fontSize(14)
            .fontColor(gc('success'))
            .backgroundColor(gc('success_bg'))
            .borderRadius(8)
            .onClick(() => {
              promptAction.showToast({ message: '功能开发中' });
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(12)
    .shadow({ radius: 4, color: '#0A000000', offsetY: 2 })
  }

  @Builder StateLabel() {
    Row() {
      if (this.task.state === TransferState.Pending) {
        Text(t('waiting'))
          .fontSize(12)
          .fontColor(gc('warning'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(gc('warning_bg'))
          .borderRadius(4)
      } else if (this.task.state === TransferState.InProgress) {
        Text(t('in_progress'))
          .fontSize(12)
          .fontColor(gc('accent'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(gc('accent_bg'))
          .borderRadius(4)
      } else if (this.task.state === TransferState.Completed) {
        Text(t('completed'))
          .fontSize(12)
          .fontColor(gc('success'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(gc('success_bg'))
          .borderRadius(4)
      } else if (this.task.state === TransferState.Failed) {
        Text(t('failed'))
          .fontSize(12)
          .fontColor(gc('error'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(gc('error_bg'))
          .borderRadius(4)
      } else if (this.task.state === TransferState.Cancelled) {
        Text(t('cancelled'))
          .fontSize(12)
          .fontColor(gc('text_secondary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(gc('divider'))
          .borderRadius(4)
      }
    }
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
          Path()
            .width(48)
            .height(48)
            .commands('M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-5 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z')
            .fill('#CCCCCC')
          
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

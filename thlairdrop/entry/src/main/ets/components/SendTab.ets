import hilog from '@ohos.hilog';
import picker from '@ohos.file.picker';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import { DeviceInfo } from '../models/DeviceInfo';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { localSendService, Device, FileInfo, DeviceType } from '../service/LocalSendService';
import { TransferProgressCard } from './TransferProgressCard';

// 文件信息接口
interface SelectedFile {
  uri: string;
  name: string | undefined;
  size: number;
}

@Component
export struct SendTab {
  @Link devices: DeviceInfo[];
  @State selectedFilesCount: number = 0;
  @State selectedFiles: SelectedFile[] = [];
  @State isScanning: boolean = false;
  @State sendTasks: TransferTask[] = [];
  @State showTransferPanel: boolean = false;

  aboutToAppear() {
    // 定期更新任务列表
    setInterval(() => {
      this.updateTasks();
    }, 500);
  }

  private updateTasks() {
    const allTasks = fileTransferManager.getAllTasks();
    this.sendTasks = allTasks.filter(t => t.direction === TransferDirection.Send);
  }

  private async selectFiles() {
    try {
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 5;
      let documentPicker = new picker.DocumentViewPicker();
      let documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult && documentSelectResult.length > 0) {
        documentSelectResult.forEach(uri => {
          this.selectedFiles.push({ uri: uri, name: uri.split('/').pop(), size: 0 });
        });
        this.selectedFilesCount = this.selectedFiles.length;
        hilog.info(0x0000, 'testTag', 'Selected files: ' + JSON.stringify(documentSelectResult));
      }
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(0x0000, 'testTag', 'Failed to select files: ' + error.message);
    }
  }

  private async selectMedia() {
    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      photoSelectOptions.maxSelectNumber = 5;
      let photoPicker = new picker.PhotoViewPicker();
      let photoSelectResult = await photoPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        photoSelectResult.photoUris.forEach(uri => {
          this.selectedFiles.push({ uri: uri, name: uri.split('/').pop(), size: 0 });
        });
        this.selectedFilesCount = this.selectedFiles.length;
        hilog.info(0x0000, 'testTag', 'Selected media: ' + JSON.stringify(photoSelectResult.photoUris));
      }
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(0x0000, 'testTag', 'Failed to select media: ' + error.message);
    }
  }

  private async sendToDevice(device: DeviceInfo) {
    if (this.selectedFilesCount === 0) {
      promptAction.showToast({ message: '请先选择要发送的文件' });
      return;
    }

    // 转换为 FileInfo 格式
    const files: FileInfo[] = this.selectedFiles.map((f: SelectedFile, index: number): FileInfo => ({
      id: `file-${index}-${Date.now()}`,
      fileName: f.name || 'unknown',
      size: f.size || 0
    }));

    // 转换设备信息
    const targetDevice: Device = {
      ip: device.address || '',
      port: device.port || 53317,
      alias: device.alias,
      fingerprint: device.fingerprint || '',
      deviceModel: device.deviceModel || 'Unknown',
      download: false,
      version: '2.0',
      https: false,
      deviceType: DeviceType.Mobile
    };

    // 创建发送任务
    const task = fileTransferManager.createSendTask(targetDevice, files);

    // 注册回调
    fileTransferManager.registerCallback(task.id, {
      onProgress: (t: TransferTask) => {
        this.updateTasks();
      },
      onComplete: (t: TransferTask) => {
        this.updateTasks();
        promptAction.showToast({ message: '文件发送完成！' });
        // 清空已发送的文件
        this.selectedFiles = [];
        this.selectedFilesCount = 0;
      },
      onError: (t: TransferTask, error: string) => {
        this.updateTasks();
        promptAction.showToast({ message: `发送失败: ${error}` });
      }
    });

    // 启动发送
    const success = await fileTransferManager.startSendTask(task.id);
    if (!success) {
      promptAction.showToast({ message: '启动发送失败' });
    } else {
      promptAction.showToast({ message: '开始发送文件...' });
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }

  build() {
    Column() {
      // 选择部分
      Column() {
        Row() {
          Text('选择')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          
          Blank()
          
          if (this.selectedFilesCount > 0) {
            Row() {
              Text(`${this.selectedFilesCount} 个文件`)
                .fontSize(12)
                .fontColor(Color.Gray)
                .margin({ right: 12 })
              
              Button('清除')
                .fontSize(12)
                .fontColor(Color.Red)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.selectedFiles = [];
                  this.selectedFilesCount = 0;
                })
            }
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 40, bottom: 10 })
        
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          this.SelectionButton('文件', 'M20,6 L12,6 L10,4 L4,4 C2.9,4 2,4.9 2,6 L2,18 C2,19.1 2.9,20 4,20 L20,20 C21.1,20 22,19.1 22,18 L22,8 C22,6.9 21.1,6 20,6 Z')
          this.SelectionButton('媒体', 'M21,19 L21,5 C21,3.9 20.1,3 19,3 L5,3 C3.9,3 3,3.9 3,5 L3,19 C3,20.1 3.9,21 5,21 L19,21 C20.1,21 21,20.1 21,19 Z M8.5,13.5 L11,16.51 L14.5,12 L19,18 L5,18 L8.5,13.5 Z')
          this.SelectionButton('文本', 'M14,2 L6,2 C4.9,2 4,2.9 4,4 L4,20 C4,21.1 4.9,22 6,22 L18,22 C19.1,22 20,21.1 20,20 L20,8 L14,2 Z M18,20 L6,20 L6,4 L13,4 L13,9 L18,9 L18,20 Z')
          this.SelectionButton('应用', 'M4,8 L8,8 L8,4 L4,4 L4,8 Z M10,20 L14,20 L14,16 L10,16 L10,20 Z M4,20 L8,20 L8,16 L4,16 L4,20 Z M4,14 L8,14 L8,10 L4,10 L4,14 Z M10,14 L14,14 L14,10 L10,10 L10,14 Z M16,4 L16,8 L20,8 L20,4 L16,4 Z M10,8 L14,8 L14,4 L10,4 L10,8 Z M16,14 L20,14 L20,10 L16,10 L16,14 Z M16,20 L20,20 L20,16 L16,16 L16,20 Z')
        }
        .padding({ left: 15, right: 15 })

        // 已选文件预览
        if (this.selectedFilesCount > 0) {
          Column() {
            ForEach(this.selectedFiles, (file: SelectedFile, index: number) => {
              Row() {
                Path()
                  .width(20)
                  .height(20)
                  .commands('M14,2 L6,2 C4.9,2 4,2.9 4,4 L4,20 C4,21.1 4.9,22 6,22 L18,22 C19.1,22 20,21.1 20,20 L20,8 L14,2 Z')
                  .fill('#007DFF')
                
                Text(file.name || 'unknown')
                  .fontSize(14)
                  .margin({ left: 8 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            })
          }
          .width('90%')
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ top: 12 })
        }
      }

      // 传输进度面板
      if (this.sendTasks.length > 0) {
        Column() {
          Row() {
            Text('传输中')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            
            Blank()
            
            Text(`${this.sendTasks.length} 个任务`)
              .fontSize(12)
              .fontColor(Color.Gray)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 8 })

          ForEach(this.sendTasks, (task: TransferTask) => {
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
        .padding({ left: 20, right: 20 })
      }

      // 附近设备
      Row() {
        Text('附近设备')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        // 扫描按钮
        Button({ type: ButtonType.Circle }) {
          Path()
            .width(24)
            .height(24)
            .commands('M17.65 6.35C16.2 4.9 14.21 4 12 4 7.58 4 4.01 7.58 4.01 12s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z')
            .fill(this.isScanning ? '#007DFF' : '#666666')
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.isScanning = true;
          // 扫描设备
          localSendService.scanDevices();
          setTimeout(() => { this.isScanning = false; }, 3000);
        })
        .rotate({ angle: this.isScanning ? 360 : 0 })
        .animation(this.isScanning ? {
          duration: 1000,
          curve: Curve.Linear,
          iterations: -1
        } : undefined)
      }
      .width('100%')
      .padding({ left: 20, right: 10, top: 20, bottom: 10 })

      List({ space: 10 }) {
        if (this.devices.length === 0) {
          ListItem() {
            Column() {
              Text(this.isScanning ? '正在扫描局域网设备...' : '未发现附近设备')
                .fontSize(16)
                .fontColor(Color.Gray)
              
              if (!this.isScanning) {
                Text('点击右上角按钮扫描')
                  .fontSize(12)
                  .fontColor('#CCCCCC')
                  .margin({ top: 4 })
              }
            }
            .width('100%')
            .height(100)
            .justifyContent(FlexAlign.Center)
          }
        }
        
        ForEach(this.devices, (device: DeviceInfo) => {
          ListItem() {
            Row() {
              // 设备图标
              Column() {
                Path()
                  .width(32)
                  .height(32)
                  .commands('M20 18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h6v2H8v2h8v-2h-2v-2h6zm-16-2V6h16v10H4z')
                  .fill('#007DFF')
              }
              .width(48)
              .height(48)
              .borderRadius(8)
              .backgroundColor('#E5F3FF')
              .justifyContent(FlexAlign.Center)
              .margin({ right: 16 })
              
              Column() {
                Text(device.alias)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                Text(`${device.deviceModel} • ${device.address}`)
                  .fontSize(12)
                  .fontColor(Color.Gray)
              }
              .alignItems(HorizontalAlign.Start)
              
              Blank()
              
              // 发送按钮
              if (this.selectedFilesCount > 0) {
                Button('发送')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor('#007DFF')
                  .borderRadius(8)
                  .height(32)
                  .onClick(() => {
                    this.sendToDevice(device);
                  })
              } else {
                Image($r('app.media.startIcon'))
                  .width(24)
                  .height(24)
                  .opacity(0.3)
              }
            }
            .width('90%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ left: '5%' })
            .onClick(() => {
              if (this.selectedFilesCount > 0) {
                this.sendToDevice(device);
              }
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)

      Text('帮助')
        .fontSize(12)
        .fontColor(Color.Gray)
        .margin({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
  }

  @Builder SelectionButton(label: string, svgPath: string) {
    Column() {
      Path()
        .width(36)
        .height(36)
        .commands(svgPath)
        .fill('#007DFF')
        .margin({ bottom: 8 })
      Text(label)
        .fontSize(16)
    }
    .width('45%')
    .height(90)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 10 })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (label === '文件') {
        this.selectFiles();
      } else if (label === '媒体') {
        this.selectMedia();
      } else if (label === '文本') {
        // 显示文本输入对话框
        promptAction.showToast({ message: '文本发送功能开发中' });
      } else {
        promptAction.showToast({ message: '应用发送功能开发中' });
      }
    })
  }
}

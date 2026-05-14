import hilog from '@ohos.hilog';
import picker from '@ohos.file.picker';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { localSendService, Device, FileInfo, DeviceType } from '../service/LocalSendService';
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

// 文件信息接口
interface SelectedFile {
  uri: string;
  name: string | undefined;
  size: number;
}

@Component
export struct SendTab {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Link devices: Device[];
  @State selectedFilesCount: number = 0;
  @State selectedFiles: SelectedFile[] = [];
  @State isScanning: boolean = false;
  
  @State showTextInputSheet: boolean = false;
  @State textToSend: string = '';

  aboutToAppear() {
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

  private async sendToDevice(device: Device) {
    if (this.selectedFilesCount === 0) {
      promptAction.showToast({ message: '请先选择要发送的文件' });
      return;
    }

    // 转换为 FileInfo 格式
    const files: FileInfo[] = this.selectedFiles.map((f: SelectedFile, index: number): FileInfo => ({
      id: `file-${index}-${Date.now()}`,
      fileName: f.name || 'unknown',
      size: f.size || 0,
      filePath: f.uri
    }));

    // 转换设备信息
    const targetDevice: Device = {
      ip: device.ip || '',
      port: device.port || 53317,
      alias: device.alias,
      fingerprint: device.fingerprint || '',
      deviceModel: device.deviceModel || 'Unknown',
      download: false,
      version: device.version || '2.0',
      https: device.https || false,
      deviceType: device.deviceType || DeviceType.Mobile
    };

    // 创建发送任务
    const task = fileTransferManager.createSendTask(targetDevice, files);

    // 注册回调
    fileTransferManager.registerCallback(task.id, {
      onProgress: (t: TransferTask) => {
      },
      onComplete: (t: TransferTask) => {
        promptAction.showToast({ message: '文件发送完成！' });
        // 清空已发送的文件
        this.selectedFiles = [];
        this.selectedFilesCount = 0;
      },
      onError: (t: TransferTask, error: string) => {
        promptAction.showToast({ message: `发送失败: ${error}` });
      }
    });

    // 启动发送
    const success = await fileTransferManager.startSendTask(task.id);
    if (!success) {
      promptAction.showToast({ message: '启动发送失败' });
    } else {
      promptAction.showToast({ message: '开始发送文件，请前往历史记录查看' });
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }

  build() {
    Scroll() {
      Column() {
        // 顶部操作栏
        Row() {
          Text('发送')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          
          Blank()
          
          Button({ type: ButtonType.Circle }) {
            Path()
              .width(36)
              .height(36)
              .commands('M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.11L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.25 2.52.77-1.28-3.52-2.09V8z')
              .fill(gc('text_primary'))
          }
          .width(56)
          .height(56)
          .backgroundColor(gc('transparent'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/TransferHistory' });
          })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 48, bottom: 20 })

        // 选择部分
        Column() {
          Row() {
            Text('选择')
              .fontSize(18)
            Text(this.selectedFilesCount > 0 ? `${t('select_files')} (${this.selectedFilesCount})` : t('select_files'))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(gc('text_primary'))
            
            Blank()
            
            if (this.selectedFilesCount > 0) {
              Text(t('clear'))
                .fontSize(14)
                .fontColor(gc('accent'))
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.selectedFiles = [];
                  this.selectedFilesCount = 0;
                })
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            this.CategoryButton(t('file'), 'M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z', (): void => { this.selectFiles(); })
            this.CategoryButton(t('media'), 'M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z', (): void => { this.selectMedia(); })
            this.CategoryButton(t('text'), 'M14 17H4v2h10v-2zm6-8H4v2h16V9zM4 15h16v-2H4v2zM4 5v2h16V5H4z', (): void => { this.showTextInputSheet = true; })
            this.CategoryButton(t('app'), 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z', (): void => { promptAction.showToast({ message: '请使用文件选择器发送 APK' }); this.selectFiles(); })
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
                    .fill(gc('accent'))
                  
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
            .backgroundColor(gc('bg_secondary'))
            .borderRadius(8)
            .margin({ top: 12 })
          }
        }

        // 附近设备
        Row() {
          Text(t('nearby_devices'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(gc('text_primary'))
          
          Blank()
          
          if (this.isScanning) {
            Text(t('scanning'))
              .fontSize(14)
              .fontColor(gc('text_secondary'))
              .margin({ right: 12 })
          }
          
          // 扫描按钮
          Button({ type: ButtonType.Circle }) {
            Path()
              .width(36)
              .height(36)
              .commands('M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z')
              .fill(this.isScanning ? gc('accent') : gc('text_tertiary'))
          }
          .width(56)
          .height(56)
          .backgroundColor(gc('transparent'))
          .onClick(() => {
            this.isScanning = true;
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
        .padding({ left: 20, right: 10, top: 30, bottom: 10 })

        List({ space: 10 }) {
          if (this.devices.length === 0) {
            ListItem() {
              Column() {
                Path()
                  .width(64)
                  .height(64)
                  .commands('M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z')
                  .fill(gc('divider'))
                Text(t('no_devices'))
                  .fontSize(16)
                  .fontColor(gc('text_tertiary'))
                  .margin({ top: 16, bottom: 8 })
                Text(t('scan_hint'))
                  .fontSize(14)
                  .fontColor(gc('text_tertiary'))
              }
              .width('100%')
              .height(200)
              .justifyContent(FlexAlign.Center)
            }
          }
          
          ForEach(this.devices, (device: Device) => {
            ListItem() {
              Row() {
                Column() {
                  Path()
                    .width(40)
                    .height(40)
                    .commands('M20 18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h6v2H8v2h8v-2h-2v-2h6zm-16-2V6h16v10H4z')
                    .fill(gc('accent'))
                }
                .width(64)
                .height(64)
                .borderRadius(12)
                .backgroundColor(gc('accent_bg'))
                .justifyContent(FlexAlign.Center)
                .margin({ right: 16 })
                
                Column() {
                  Text(device.alias)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                  Text(`${device.deviceModel || 'Unknown'} • ${device.ip}`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                
                Blank()
                
                if (this.selectedFilesCount > 0) {
                  Button('发送')
                    .fontSize(14)
                    .fontColor(Color.White)
                    .backgroundColor('#007DFF')
                    .borderRadius(8)
                    .height(36)
                    .onClick(() => {
                      this.sendToDevice(device);
                    })
                } else {
                  Image($r('app.media.startIcon'))
                    .width(28)
                    .height(28)
                    .opacity(0.3)
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(gc('bg_secondary'))
              .borderRadius(16)
              .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
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
          .margin({ bottom: 40, top: 20 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(gc('bg_primary'))
    .bindSheet(this.showTextInputSheet, this.TextInputSheet(), {
      height: 300,
      backgroundColor: gc('bg_secondary'),
      dragBar: true
    })
  }

  @Builder CategoryButton(label: string, svgPath: string, onClick: () => void) {
    Column() {
      Path()
        .width(48)
        .height(48)
        .commands(svgPath)
        .fill(gc('accent'))
        .margin({ bottom: 12 })
      Text(label)
        .fontSize(18)
        .fontColor(gc('text_primary'))
    }
    .width('48%')
    .height(120)
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(16)
    .margin({ bottom: 12 })
    .justifyContent(FlexAlign.Center)
    .onClick(onClick)
  }

  @Builder TextInputSheet() {
    Column() {
      Text(t('send_text_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary'))
        .margin({ top: 16, bottom: 16 })
      
      TextArea({ text: this.textToSend, placeholder: t('input_text_placeholder') })
        .width('90%')
        .height(120)
        .onChange((value: string) => {
          this.textToSend = value;
        })
      
      Row() {
        Button(t('cancel'))
          .width('40%')
          .backgroundColor(gc('bg_primary'))
          .fontColor(gc('text_primary'))
          .onClick(() => {
            this.showTextInputSheet = false;
            this.textToSend = '';
          })
        
        Button(t('confirm'))
          .width('40%')
          .onClick(() => {
            if (this.textToSend.trim()) {
              this.selectedFiles.push({
                uri: 'text://' + this.textToSend.substring(0, 10),
                name: '文本消息.txt',
                size: this.textToSend.length
              });
              this.selectedFilesCount = this.selectedFiles.length;
            }
            this.showTextInputSheet = false;
            this.textToSend = '';
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 20 })
    }
    .width('100%')
    .padding(16)
  }

  @Builder SelectionButton(label: string, svgPath: string) {
    Column() {
      Path()
        .width(48)
        .height(48)
        .commands(svgPath)
        .fill('#007DFF')
        .margin({ bottom: 12 })
      Text(label)
        .fontSize(18)
    }
    .width('48%')
    .height(120)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin({ bottom: 12 })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (label === '文件') {
        this.selectFiles();
      } else if (label === '媒体') {
        this.selectMedia();
      } else if (label === '文本') {
        this.showTextInputSheet = true;
      } else {
        promptAction.showToast({ message: '由于系统限制，请在文件选择中选取安装包' });
        this.selectFiles();
      }
    })
  }
}

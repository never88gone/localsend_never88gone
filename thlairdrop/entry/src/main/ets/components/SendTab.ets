import hilog from '@ohos.hilog';
import picker from '@ohos.file.picker';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { fileTransferManager, TransferTask, TransferState, TransferDirection } from '../service/FileTransferManager';
import { localSendService, Device, FileInfo, DeviceType } from '../service/LocalSendService';
import { SettingsService } from '../services/SettingsService';
import { gc, ThemeManager } from '../utils/ThemeManager';
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
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @Link devices: Device[];
  
  onRefreshTriggered() {
    this.refreshKey++;
  }
  @State selectedFilesCount: number = 0;
  @State selectedFiles: SelectedFile[] = [];
  @State isScanning: boolean = false;
  
  @State showTextInputSheet: boolean = false;
  @State textToSend: string = '';

  // 根据设备模型获取设备图标
  private getDeviceIcon(deviceModel: string): Resource {
    const model = deviceModel.toLowerCase();
    // 手机设备 - 使用手机图标
    if (model.includes('iphone') || model.includes('ipad') || model.includes('ios') ||
        model.includes('android') || model.includes('harmony') || model.includes('harmonyos')) {
      return $r('sys.symbol.phone');
    }
    // 桌面设备 - 使用显示器图标
    if (model.includes('windows') || model.includes('mac') || model.includes('macos') || model.includes('linux')) {
      return $r('sys.symbol.display');
    }
    // TV 设备 - 使用显示器图标
    if (model.includes('tv')) {
      return $r('sys.symbol.display');
    }
    // 默认设备图标
    return $r('sys.symbol.display');
  }

  // 根据设备模型获取设备类型名称
  private getDeviceTypeName(deviceModel: string): string {
    const model = deviceModel.toLowerCase();
    if (model.includes('iphone') || model.includes('ipad') || model.includes('ios')) {
      return 'iOS';
    } else if (model.includes('android')) {
      return 'Android';
    } else if (model.includes('harmony') || model.includes('harmonyos')) {
      return 'HarmonyOS';
    } else if (model.includes('windows')) {
      return 'Windows';
    } else if (model.includes('mac') || model.includes('macos')) {
      return 'macOS';
    } else if (model.includes('linux')) {
      return 'Linux';
    } else if (model.includes('tv')) {
      return 'TV';
    } else {
      return deviceModel || 'Unknown';
    }
  }

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
            SymbolGlyph($r('sys.symbol.clock'))
              .fontSize(24)
              .fontColor([gc('text_primary')])
          }
          .width(56)
          .height(56)
          .backgroundColor(gc('transparent'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/TransferHistory' });
          })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 20, bottom: 20 })

        // 选择部分
        Column() {
          Row() {
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
            this.CategoryButton(t('file'), $r('sys.symbol.doc'), (): void => { this.selectFiles(); })
            this.CategoryButton(t('media'), $r('sys.symbol.camera'), (): void => { this.selectMedia(); })
            this.CategoryButton(t('text'), $r('sys.symbol.textformat'), (): void => { this.showTextInputSheet = true; })
          }
          .padding({ left: 15, right: 15 })

          // 已选文件预览
          if (this.selectedFilesCount > 0) {
            Column() {
              ForEach(this.selectedFiles, (file: SelectedFile, index: number) => {
                Row() {
                  SymbolGlyph($r('sys.symbol.doc'))
                    .fontSize(20)
                    .fontColor([gc('accent')])
                  
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
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(24)
              .fontColor([this.isScanning ? gc('accent') : gc('text_tertiary')])
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
                SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                  .fontSize(64)
                  .fontColor([gc('divider')])
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
                  SymbolGlyph(this.getDeviceIcon(device.deviceModel))
                    .fontSize(40)
                    .fontColor([gc('accent')])
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
                  Text(`${this.getDeviceTypeName(device.deviceModel)} • ${device.ip || 'Unknown'}`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                
                Blank()

                // 收藏按钮
                FavoriteButton({ fingerprint: device.fingerprint })
                
                if (this.selectedFilesCount > 0) {
                  Button('发送')
                    .fontSize(14)
                    .fontColor(Color.White)
                    .backgroundColor('#007DFF')
                    .borderRadius(8)
                    .height(36)
                    .margin({ left: 12 })
                    .onClick(() => {
                      this.sendToDevice(device);
                    })
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

        Text(t('help'))
          .fontSize(14)
          .fontColor(gc('accent'))
          .margin({ bottom: 40, top: 20 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/HelpPage' });
          })
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
    .key(`send_tab_scroll_${this.refreshKey}`)
  }

  @Builder CategoryButton(label: string, iconResource: Resource, onClick: () => void) {
    CategoryButtonComponent({ label: label, iconResource: iconResource, onButtonClick: onClick })
  }

  @Builder TextInputSheet() {
// ...
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

  @Builder SelectionButton(label: string, iconResource: Resource) {
    Column() {
      SymbolGlyph(iconResource)
        .fontSize(48)
        .fontColor(['#007DFF'])
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

/**
 * 收藏按钮组件
 */
@Component
struct FavoriteButton {
  @Prop fingerprint: string;
  @State isFav: boolean = false;
  private settingsService = SettingsService.getInstance();

  async aboutToAppear() {
    this.isFav = await this.settingsService.isFavorite(this.fingerprint);
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.isFav ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
        .fontSize(24)
        .fontColor([this.isFav ? gc('accent') : gc('text_tertiary')])
    }
    .width(44)
    .height(44)
    .backgroundColor(gc('transparent'))
    .onClick(async (event: ClickEvent) => {
      // 阻止冒泡到 ListItem 点击
      this.isFav = !this.isFav;
      await this.settingsService.toggleFavorite(this.fingerprint);
    })
  }
}

@Component
struct CategoryButtonComponent {
  @Prop label: string;
  @Prop iconResource: Resource;
  onButtonClick: () => void = () => {};
  @State scaleVal: number = 1.0;

  build() {
    Column() {
      SymbolGlyph(this.iconResource)
        .fontSize(36)
        .fontColor([gc('accent')])
        .margin({ bottom: 8 })
      Text(this.label)
        .fontSize(16)
        .fontColor(gc('text_primary'))
    }
    .width('48%')
    .height(90)
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(16)
    .margin({ bottom: 12 })
    .justifyContent(FlexAlign.Center)
    .scale({ x: this.scaleVal, y: this.scaleVal })
    .animation({
      duration: 200,
      curve: Curve.EaseInOut
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.scaleVal = 0.92;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.scaleVal = 1.0;
      }
    })
    .onClick(this.onButtonClick)
  }
}

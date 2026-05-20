import hilog from '@ohos.hilog';
import picker from '@ohos.file.picker';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import fs from '@ohos.file.fs';
import wantConstant from '@ohos.app.ability.wantConstant';
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
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
  type?: string; // 'file' | 'media' | 'text'
}

@Component
export struct SendTab {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @Link devices: Device[];
  
  // 语言版本变化时触发UI刷新
  onRefreshTriggered() {
    // 强制触发UI重新渲染
    this.refreshKey = this.themeVersion + this.languageVersion;
  }
  @State selectedFilesCount: number = 0;
  @State selectedFiles: SelectedFile[] = [];
  @State isScanning: boolean = false;
  
  @State textToSend: string = '';

  private textInputDialogController: CustomDialogController | null = new CustomDialogController({
    builder: TextInputDialog({
      textToSend: $textToSend,
      onConfirm: () => {
        if (this.textToSend.trim()) {
          this.selectedFiles.push({
            uri: 'text://' + this.textToSend.substring(0, 10),
            name: 'Text Message.txt',
            size: this.textToSend.length,
            type: 'text'
          });
          this.selectedFilesCount = this.selectedFiles.length;
        }
        this.textToSend = '';
      },
      onCancel: () => {
        this.textToSend = '';
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  // 根据设备模型和设备类型获取设备图标
  private getDeviceIcon(deviceModel: string, deviceType: string): Resource {
    const model = (deviceModel || '').toLowerCase();
    const type = (deviceType || '').toLowerCase();
    
    // 1. 平板电脑 - 使用平板图标
    if (model.includes('ipad') || model.includes('tablet')) {
      return $r('sys.symbol.pad');
    }
    // 2. 电视设备 - 使用电视图标
    if (model.includes('tv') || type === 'tv') {
      return $r('sys.symbol.smartscreen');
    }
    // 3. 笔记本电脑 - 使用笔记本图标
    if (model.includes('macbook') || model.includes('laptop')) {
      return $r('sys.symbol.matebook');
    }
    // 4. 桌面电脑 - 使用显示器图标
    if (model.includes('windows') || model.includes('mac') || model.includes('macos') || model.includes('linux') || type === 'desktop') {
      return $r('sys.symbol.display');
    }
    // 5. 手机设备 - 使用手机图标
    if (model.includes('iphone') || model.includes('phone') || model.includes('android') || 
        model.includes('harmony') || model.includes('harmonyos') || type === 'mobile') {
      return $r('sys.symbol.phone');
    }
    // 默认设备图标
    return $r('sys.symbol.phone');
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

  private cleanupTempFiles(paths: string[]) {
    setTimeout(() => {
      paths.forEach(path => {
        try {
          if (fs.accessSync(path)) {
            fs.unlinkSync(path);
            hilog.info(0x0000, 'SendTab', `Cleaned up temp file: ${path}`);
          }
        } catch (e) {
          hilog.error(0x0000, 'SendTab', `Failed to delete temp file ${path}: ${(e as Error).message}`);
        }
      });
    }, 2000);
  }

  private async selectFiles() {
    try {
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 5;
      let documentPicker = new picker.DocumentViewPicker();
      let documentSelectResult = await documentPicker.select(documentSelectOptions);
      if (documentSelectResult && documentSelectResult.length > 0) {
        documentSelectResult.forEach(uri => {
          let name = uri.split('/').pop() || 'unknown';
          let size = 0;
          try {
            let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
            let stat = fs.statSync(file.fd);
            size = stat.size;
            fs.closeSync(file);
          } catch (e) {
            hilog.error(0x0000, 'testTag', 'Failed to get file stat: ' + (e as Error).message);
          }
          this.selectedFiles.push({ uri: uri, name: name, size: size, type: 'file' });
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
          let name = uri.split('/').pop() || 'unknown';
          let size = 0;
          try {
            let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
            let stat = fs.statSync(file.fd);
            size = stat.size;
            fs.closeSync(file);
          } catch (e) {
            hilog.error(0x0000, 'testTag', 'Failed to get media stat: ' + (e as Error).message);
          }
          this.selectedFiles.push({ uri: uri, name: name, size: size, type: 'media' });
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
      promptAction.showToast({ message: t('select_files', this.languageVersion) });
      return;
    }

    const context = SettingsService.getInstance().getContext();
    if (!context) {
      promptAction.showToast({ message: '无法获取上下文' });
      return;
    }

    promptAction.showToast({ message: '正在准备发送文件...' });

    const preparedFiles: FileInfo[] = [];
    const tempPaths: string[] = [];

    for (let i = 0; i < this.selectedFiles.length; i++) {
      const f = this.selectedFiles[i];
      if (f.uri.startsWith('text://')) {
        // 文本：写入临时文件
        const textContent = f.uri.substring(7);
        const tempFileName = `text-${Date.now()}-${i}.txt`;
        const tempPath = `${context.cacheDir}/${tempFileName}`;
        try {
          let file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, textContent);
          fs.closeSync(file);

          preparedFiles.push({
            id: `file-${i}-${Date.now()}`,
            fileName: f.name || 'Text Message.txt',
            size: fs.statSync(tempPath).size,
            filePath: tempPath   // C++ 可直接 fopen 的真实路径
          });
          tempPaths.push(tempPath);
        } catch (e) {
          hilog.error(0x0000, 'SendTab', `Failed to write text temp file: ${(e as Error).message}`);
          promptAction.showToast({ message: `准备文本文件失败: ${(e as Error).message}` });
          this.cleanupTempFiles(tempPaths);
          return;
        }
      } else {
        // 普通文件/媒体：复制到 cacheDir，得到 C++ 可访问的真实路径
        const ext = (f.name || 'file').includes('.') ? (f.name || 'file').split('.').pop() : 'bin';
        const tempFileName = `send-${Date.now()}-${i}.${ext}`;
        const tempPath = `${context.cacheDir}/${tempFileName}`;
        let srcFile: fs.File | null = null;
        try {
          // 使用 fs.openSync 打开源文件 URI，系统会自动解析 datashare:// 和 file:// 格式的虚拟 URI 并返回 fd
          srcFile = fs.openSync(f.uri, fs.OpenMode.READ_ONLY);
          fs.copyFileSync(srcFile.fd, tempPath);
          fs.closeSync(srcFile);
          srcFile = null;

          const stat = fs.statSync(tempPath);

          preparedFiles.push({
            id: `file-${i}-${Date.now()}`,
            fileName: f.name || 'unknown',
            size: stat.size,
            filePath: tempPath   // C++ 可直接 fopen 的真实路径
          });
          tempPaths.push(tempPath);
        } catch (e) {
          if (srcFile) {
            try {
              fs.closeSync(srcFile);
            } catch (closeErr) {
              // 忽略关闭失败
            }
          }
          hilog.error(0x0000, 'SendTab', `Failed to copy file to cache: ${(e as Error).message}`);
          promptAction.showToast({ message: `准备文件 ${f.name} 失败: ${(e as Error).message}` });
          this.cleanupTempFiles(tempPaths);
          return;
        }
      }
    }

    const targetDevice: Device = {
      ip: device.ip || '',
      port: device.port || 53317,
      alias: device.alias,
      fingerprint: device.fingerprint || '',
      deviceModel: device.deviceModel || 'Unknown',
      download: false,
      version: device.version || '2.0',
      https: device.https !== undefined ? device.https : true,
      deviceType: device.deviceType || DeviceType.Mobile
    };

    const task = fileTransferManager.createSendTask(targetDevice, preparedFiles);

    fileTransferManager.registerCallback(task.id, {
      onProgress: (progressTask: TransferTask) => {
      },
      onComplete: (completeTask: TransferTask) => {
        promptAction.showToast({ message: t('completed', this.languageVersion) });
        this.selectedFiles = [];
        this.selectedFilesCount = 0;
        this.cleanupTempFiles(tempPaths);
      },
      onError: (errorTask: TransferTask, error: string) => {
        promptAction.showToast({ message: `${t('failed', this.languageVersion)}: ${error}` });
        this.cleanupTempFiles(tempPaths);
      }
    });

    const success = await fileTransferManager.startSendTask(task.id);
    if (!success) {
      promptAction.showToast({ message: t('failed', this.languageVersion) });
      this.cleanupTempFiles(tempPaths);
    } else {
      promptAction.showToast({ message: t('in_progress', this.languageVersion) });
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }

  private getMimeType(fileName: string): string {
    const ext = fileName.split('.').pop()?.toLowerCase();
    const mimeMap: Record<string, string> = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'html': 'text/html',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'zip': 'application/zip',
      'apk': 'application/vnd.android.package-archive'
    };
    return mimeMap[ext || ''] || '*/*';
  }

  private async previewFile(file: SelectedFile) {
    if (!file.uri) {
      promptAction.showToast({ message: '文件路径不存在' });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const mimeType = this.getMimeType(file.name || '');

      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: file.uri,
        type: mimeType,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };

      await context.startAbility(want);
      console.info(`[SendTab] Successfully opened file for preview: ${file.uri}`);
    } catch (err) {
      promptAction.showToast({ message: '未找到支持打开该文件的应用' });
      console.error('[SendTab] Failed to preview file:', err);
    }
  }

  build() {
    Column() {
      // 顶部操作栏 (固定在顶部，不随内容滚动)
      Row() {
        Text(t('tab_send', this.languageVersion))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary', this.themeVersion))
        
        Blank()
        
        // 帮助按钮 (问号圆圈图标)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(24)
            .fontColor([gc('text_primary', this.themeVersion)])
        }
        .width(48)
        .height(48)
        .backgroundColor(gc('transparent', this.themeVersion))
        .margin({ right: 8 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/HelpPage' });
        })
        
        // 历史记录按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(24)
            .fontColor([gc('text_primary', this.themeVersion)])
        }
        .width(48)
        .height(48)
        .backgroundColor(gc('transparent', this.themeVersion))
        .onClick(() => {
          router.pushUrl({ url: 'pages/TransferHistory' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      // 可滚动内容区
      Scroll() {
        Column() {
          // 选择部分
          Column() {
            Row() {
              Text(this.selectedFilesCount > 0 ? `${t('select_files', this.languageVersion)} (${this.selectedFilesCount})` : t('select_files', this.languageVersion))
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary', this.themeVersion))
              
              Blank()
              
              if (this.selectedFilesCount > 0) {
                Text(t('clear', this.languageVersion))
                  .fontSize(14)
                  .fontColor(gc('accent', this.themeVersion))
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.selectedFiles = [];
                    this.selectedFilesCount = 0;
                  })
              }
            }
            .width('100%')
            .padding({ left: 0, right: 0, top: 10, bottom: 10 })
            
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.CategoryButton('file', $r('sys.symbol.doc'), (): void => { this.selectFiles(); })
              this.CategoryButton('media', $r('sys.symbol.camera'), (): void => { this.selectMedia(); })
              this.CategoryButton('text', $r('sys.symbol.textformat'), (): void => {
                if (this.textInputDialogController) {
                  this.textInputDialogController.open();
                }
              })
            }
            .padding({ left: 0, right: 0 })

            // 已选文件预览
            if (this.selectedFilesCount > 0) {
              Column() {
                ForEach(this.selectedFiles, (file: SelectedFile, index: number) => {
                  Row() {
                    // 主体点击可预览/定位
                    Row() {
                      SymbolGlyph(file.type === 'media' ? $r('sys.symbol.camera') : (file.type === 'text' ? $r('sys.symbol.textformat') : $r('sys.symbol.doc')))
                        .fontSize(24)
                        .fontColor([gc('text_secondary', this.themeVersion)])
                        .margin({ right: 12 })
                      
                      Column() {
                        Text(file.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(gc('text_primary', this.themeVersion))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        
                        Row() {
                          Text(this.formatSize(file.size))
                            .fontSize(12)
                            .fontColor(gc('text_tertiary', this.themeVersion))
                          
                          Text('  •  ')
                            .fontSize(11)
                            .fontColor(gc('text_tertiary', this.themeVersion))
                          
                          // 优雅展示文件的原始定位路径
                          Text(file.uri)
                            .fontSize(11)
                            .fontColor(gc('text_tertiary', this.themeVersion))
                            .layoutWeight(1)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .width('100%')
                        .margin({ top: 4 })
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                    }
                    .layoutWeight(1)
                    .onClick(() => {
                      this.previewFile(file);
                    })
                    
                    // 显式预览定位的动作入口
                    Button({ type: ButtonType.Circle }) {
                      SymbolGlyph($r('sys.symbol.eye'))
                        .fontSize(18)
                        .fontColor([gc('accent', this.themeVersion)])
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(gc('transparent', this.themeVersion))
                    .margin({ right: 4 })
                    .onClick(() => {
                      this.previewFile(file);
                    })

                    // 移除该选项的按钮
                    Button({ type: ButtonType.Circle }) {
                      SymbolGlyph($r('sys.symbol.xmark'))
                        .fontSize(16)
                        .fontColor([gc('text_secondary', this.themeVersion)])
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(gc('transparent', this.themeVersion))
                    .onClick(() => {
                      this.selectedFiles.splice(index, 1);
                      this.selectedFilesCount = this.selectedFiles.length;
                    })
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  
                  if (index < this.selectedFiles.length - 1) {
                    Divider().color(gc('divider', this.themeVersion)).strokeWidth(1)
                  }
                })
              }
              .width('100%')
              .backgroundColor(gc('bg_secondary', this.themeVersion))
              .borderRadius(16)
              .padding({ left: 16, right: 16 })
              .margin({ top: 16 })
              .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            }
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 设备列表部分
          Row() {
            Text(t('nearby_devices', this.languageVersion))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(gc('text_primary', this.themeVersion))
            
            Blank()
            
            // 扫描状态指示器 / 刷新按钮
            if (this.isScanning) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color(gc('accent', this.themeVersion))
            } else {
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(20)
                  .fontColor([gc('accent', this.themeVersion)])
              }
              .width(36)
              .height(36)
              .backgroundColor(gc('transparent', this.themeVersion))
              .onClick(() => {
                this.isScanning = true;
                localSendService.scanDevices();
                setTimeout(() => { this.isScanning = false; }, 3000);
              })
            }
          }
          .width('100%')
          .padding({ left: 0, right: 0, top: 10, bottom: 10 })

          if (this.devices.length === 0) {
            Column() {
              SymbolGlyph($r('sys.symbol.wifi'))
                .fontSize(48)
                .fontColor([gc('divider', this.themeVersion)])
                .margin({ bottom: 12 })
              
              Text(t('no_devices', this.languageVersion))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary', this.themeVersion))
                .margin({ bottom: 8 })

              Text(t('scan_hint', this.languageVersion))
                .fontSize(14)
                .fontColor(gc('text_secondary', this.themeVersion))
                .textAlign(TextAlign.Center)
                .margin({ bottom: 16 })

              Button() {
                Row() {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(16)
                    .fontColor([Color.White])
                    .margin({ right: 6 })
                  Text(t('help', this.languageVersion))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
              }
              .height(36)
              .padding({ left: 16, right: 16 })
              .backgroundColor(gc('accent', this.themeVersion))
              .borderRadius(18)
              .onClick(() => {
                router.pushUrl({ url: 'pages/HelpPage' });
              })
            }
            .width('100%')
            .padding({ top: 30, bottom: 30, left: 16, right: 16 })
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
          }

          ForEach(this.devices, (device: Device) => {
            Column() {
              Row() {
                // 根据设备类型显示图标
                SymbolGlyph(this.getDeviceIcon(device.deviceModel, device.deviceType))
                  .fontSize(32)
                  .fontColor([gc('accent', this.themeVersion)])
                  .margin({ right: 16 })
                
                Column() {
                  Text(device.alias)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(gc('text_primary', this.themeVersion))
                  
                  Row() {
                    Text(device.ip + ':' + device.port)
                      .fontSize(12)
                      .fontColor(gc('text_secondary', this.themeVersion))
                    
                    Text(' • ')
                      .fontSize(12)
                      .fontColor(gc('text_tertiary', this.themeVersion))
                    
                    Text(device.deviceModel || device.deviceType || 'Unknown')
                      .fontSize(12)
                      .fontColor(gc('text_secondary', this.themeVersion))
                  }
                  .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                
                if (this.selectedFilesCount > 0) {
                  Button() {
                    Text(t('tab_send', this.languageVersion))
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .height(36)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(gc('accent', this.themeVersion))
                  .borderRadius(18)
                  .onClick(() => {
                    this.sendToDevice(device);
                  })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(gc('bg_secondary', this.themeVersion))
              .borderRadius(16)
              .onClick(() => {
                if (this.selectedFilesCount > 0) {
                  this.sendToDevice(device);
                }
              })
            }
            .width('100%')
            .margin({ top: 8, bottom: 8 })
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
          })

          // 底部帮助提示，引导用户解决无法发现设备的问题
          if (this.devices.length > 0) {
            Column() {
              Button({ type: ButtonType.Normal }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(16)
                    .fontColor([gc('accent', this.themeVersion)])
                    .margin({ right: 6 })
                  Text(t('help', this.languageVersion))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(gc('accent', this.themeVersion))
                }
              }
              .backgroundColor(Color.Transparent)
              .borderRadius(8)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/HelpPage' });
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 24, bottom: 16 })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .key(`send_tab_scroll_${this.refreshKey}`)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .key(`send_tab_scroll_${this.refreshKey}`)
  }

  @Builder CategoryButton(labelKey: string, iconResource: Resource, onClick: () => void) {
    CategoryButtonComponent({ labelKey: labelKey, iconResource: iconResource, onButtonClick: onClick, themeVersion: this.themeVersion, languageVersion: this.languageVersion })
  }

}

/**
 * 收藏按钮组件
 */
@Component
struct FavoriteButton {
  @Prop fingerprint: string;
  @Prop themeVersion: number;
  @Prop languageVersion: number;
  @State isFav: boolean = false;
  private settingsService = SettingsService.getInstance();

  async aboutToAppear() {
    this.isFav = await this.settingsService.isFavorite(this.fingerprint);
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.isFav ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
        .fontSize(24)
        .fontColor([this.isFav ? gc('accent', this.themeVersion) : gc('text_tertiary', this.themeVersion)])
    }
    .width(44)
    .height(44)
    .backgroundColor(gc('transparent', this.themeVersion))
    .onClick(async (event: ClickEvent) => {
      this.isFav = !this.isFav;
      await this.settingsService.toggleFavorite(this.fingerprint);
    })
  }
}

@Component
struct CategoryButtonComponent {
  @Prop labelKey: string;
  @Prop iconResource: Resource;
  @Prop themeVersion: number;
  @Prop languageVersion: number;
  onButtonClick: () => void = () => {};
  @State scaleVal: number = 1.0;
  @State isPressed: boolean = false;

  build() {
    Column() {
      SymbolGlyph(this.iconResource)
        .fontSize(36)
        .fontColor([gc('accent', this.themeVersion)])
        .margin({ bottom: 8 })
      Text(t(this.labelKey, this.languageVersion))
        .fontSize(16)
        .fontColor(gc('text_primary', this.themeVersion))
    }
    .width('31%')
    .height(90)
    .backgroundColor(this.isPressed ? gc('accent_bg', this.themeVersion) : gc('bg_secondary', this.themeVersion))
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
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.scaleVal = 1.0;
        this.isPressed = false;
      }
    })
    .onClick(this.onButtonClick)
  }
}

/**
 * 文本输入弹窗组件，居中展示且默认自动避让键盘
 */
@CustomDialog
struct TextInputDialog {
  controller: CustomDialogController;
  @Link textToSend: string;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
  
  @StorageProp('themeVersion') themeVersion: number = 0;
  @StorageProp('languageVersion') languageVersion: number = 0;

  build() {
    Column() {
      // 标题
      Text(t('send_text_title', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 8, bottom: 16 })
      
      // 输入域
      TextArea({ text: this.textToSend, placeholder: t('input_text_placeholder', this.languageVersion) })
        .width('100%')
        .height(130)
        .fontSize(15)
        .fontColor(gc('text_primary', this.themeVersion))
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .placeholderColor(gc('text_tertiary', this.themeVersion))
        .borderRadius(10)
        .onChange((value: string) => {
          this.textToSend = value;
        })
        .margin({ bottom: 20 })
      
      // 按钮操作区
      Row() {
        Button(t('cancel', this.languageVersion))
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(gc('text_secondary', this.themeVersion))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: gc('divider', this.themeVersion) })
          .borderRadius(12)
          .height(42)
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
        
        Blank().width(16)
        
        Button(t('confirm', this.languageVersion))
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(gc('accent', this.themeVersion))
          .borderRadius(12)
          .height(42)
          .onClick(() => {
            this.onConfirm();
            this.controller.close();
          })
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
    .width('90%')
    .padding(20)
    .backgroundColor(gc('bg_secondary', this.themeVersion))
    .borderRadius(16)
  }
}

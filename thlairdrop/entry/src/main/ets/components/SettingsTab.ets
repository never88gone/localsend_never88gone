import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import { SettingsService, AppSettings } from '../services/SettingsService';

// 设置项接口
interface SettingsItem {
  label: string;
  value: string;
  key: string;
  isToggle?: boolean;
  isOn?: boolean;
  onClick?: () => void;
}

@Component
export struct SettingsTab {
  @Link aliasName: string;
  @Link quickSaveMode: number;
  @Link animationEnabled: boolean;
  @Link port: number;
  
  // 设置服务
  private settingsService: SettingsService = SettingsService.getInstance();
  private context: common.UIAbilityContext | null = null;
  
  // 设置状态
  @State theme: string = 'system';
  @State language: string = 'zh';
  @State encryptionEnabled: boolean = true;
  @State saveDir: string = '下载';
  
  // 弹窗状态
  @State showAliasDialog: boolean = false;
  @State showPortDialog: boolean = false;
  @State tempAliasName: string = '';
  @State tempPort: string = '';
  
  aboutToAppear(): void {
    // 获取 context
    this.context = getContext(this) as common.UIAbilityContext;
    // 加载保存的设置
    this.loadSettings();
  }
  
  // 加载设置
  private loadSettings(): void {
    this.settingsService.getSettings().then((settings: AppSettings) => {
      this.theme = settings.theme;
      this.language = settings.language;
      this.animationEnabled = settings.animationEnabled;
      this.quickSaveMode = settings.quickSaveMode;
      this.saveDir = settings.saveDir;
      this.port = settings.port;
      this.encryptionEnabled = settings.encryptionEnabled;
      this.aliasName = settings.aliasName;
    }).catch((err: Error) => {
      hilog.error(0x0000, 'SettingsTab', `Failed to load settings: ${err.message}`);
    });
  }

  build() {
    Scroll() {
      Column() {
        Text('设置')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 32, top: 48, bottom: 24 })

        this.SettingsSection('常规', [
          { 
            label: '主题', 
            value: this.settingsService.getThemeDisplayName(this.theme), 
            key: 'theme',
            onClick: (): void => this.showThemePicker()
          },
          { 
            label: '语言', 
            value: this.settingsService.getLanguageDisplayName(this.language), 
            key: 'lang',
            onClick: (): void => this.showLanguagePicker()
          },
          { 
            label: '动画', 
            value: '', 
            isToggle: true, 
            isOn: this.animationEnabled,
            key: 'anim',
            onClick: (): void => this.toggleAnimation()
          }
        ])

        this.SettingsSection('接收', [
          { 
            label: '快速保存', 
            value: this.settingsService.getQuickSaveModeDisplayName(this.quickSaveMode),
            key: 'quickSave',
            onClick: (): void => this.showQuickSavePicker()
          },
          { 
            label: '保存目录', 
            value: this.saveDir,
            key: 'dir',
            onClick: (): void => this.selectSaveDir()
          }
        ])

        this.SettingsSection('网络', [
          { 
            label: '别名', 
            value: this.aliasName, 
            key: 'alias',
            onClick: (): void => this.showAliasInputDialog()
          },
          { 
            label: '端口', 
            value: this.port.toString(),
            key: 'port',
            onClick: (): void => this.showPortInputDialog()
          },
          { 
            label: '加密', 
            value: '', 
            isToggle: true, 
            isOn: this.encryptionEnabled,
            key: 'encryption',
            onClick: (): void => this.toggleEncryption()
          }
        ])

        // 关于
        Column() {
          Image($r('app.media.app_icon'))
            .width(80).height(80)
            .borderRadius(16)
            .margin({ top: 48, bottom: 12 })
          Text('糖葫芦投送')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Text('版本: 1.0.0')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 4 })
          Text('© 2024 糖葫芦团队')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 64 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
    .bindSheet(this.showAliasDialog, this.AliasInputDialog(), {
      height: 200,
      backgroundColor: Color.White,
      dragBar: true
    })
    .bindSheet(this.showPortDialog, this.PortInputDialog(), {
      height: 200,
      backgroundColor: Color.White,
      dragBar: true
    })
  }

  // 别名输入弹窗
  @Builder AliasInputDialog() {
    Column() {
      Text('修改别名')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempAliasName, placeholder: '请输入设备别名' })
        .width('90%')
        .height(48)
        .onChange((value: string) => {
          this.tempAliasName = value;
        })
      
      Row() {
        Button('取消')
          .width('40%')
          .backgroundColor('#F1F3F5')
          .fontColor('#333333')
          .onClick(() => {
            this.showAliasDialog = false;
          })
        
        Button('确定')
          .width('40%')
          .onClick(() => {
            if (this.tempAliasName.trim()) {
              this.aliasName = this.tempAliasName.trim();
              this.settingsService.setAliasName(this.aliasName);
              promptAction.showToast({ message: '别名已修改为: ' + this.aliasName });
            }
            this.showAliasDialog = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 20 })
    }
    .width('100%')
    .padding(16)
  }

  // 端口输入弹窗
  @Builder PortInputDialog() {
    Column() {
      Text('修改端口')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempPort, placeholder: '请输入端口号 (1024-65535)' })
        .width('90%')
        .height(48)
        .type(InputType.Number)
        .onChange((value: string) => {
          this.tempPort = value;
        })
      
      Row() {
        Button('取消')
          .width('40%')
          .backgroundColor('#F1F3F5')
          .fontColor('#333333')
          .onClick(() => {
            this.showPortDialog = false;
          })
        
        Button('确定')
          .width('40%')
          .onClick(() => {
            const newPort = parseInt(this.tempPort);
            if (newPort >= 1024 && newPort <= 65535) {
              this.port = newPort;
              this.settingsService.setPort(this.port);
              promptAction.showToast({ message: `端口已修改为: ${this.port}，请重启应用生效` });
            } else {
              promptAction.showToast({ message: '端口号无效，请输入 1024-65535 之间的数字' });
            }
            this.showPortDialog = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 20 })
    }
    .width('100%')
    .padding(16)
  }

  // 显示主题选择器
  private showThemePicker() {
    promptAction.showDialog({
      title: '选择主题',
      buttons: [
        { text: '跟随系统', color: this.theme === 'system' ? '#007DFF' : '#333333' },
        { text: '浅色模式', color: this.theme === 'light' ? '#007DFF' : '#333333' },
        { text: '深色模式', color: this.theme === 'dark' ? '#007DFF' : '#333333' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      const themes: string[] = ['system', 'light', 'dark'];
      this.theme = themes[result.index];
      this.settingsService.setTheme(this.theme);
      promptAction.showToast({ message: '主题已切换为: ' + this.settingsService.getThemeDisplayName(this.theme) });
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'SettingsTab', `Theme picker error: ${err.message}`);
    });
  }

  // 显示语言选择器
  private showLanguagePicker() {
    promptAction.showDialog({
      title: '选择语言',
      buttons: [
        { text: '中文', color: this.language === 'zh' ? '#007DFF' : '#333333' },
        { text: 'English', color: this.language === 'en' ? '#007DFF' : '#333333' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      const languages: string[] = ['zh', 'en'];
      this.language = languages[result.index];
      this.settingsService.setLanguage(this.language);
      promptAction.showToast({ message: '语言已切换为: ' + this.settingsService.getLanguageDisplayName(this.language) });
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'SettingsTab', `Language picker error: ${err.message}`);
    });
  }

  // 显示快速保存选择器
  private showQuickSavePicker() {
    promptAction.showDialog({
      title: '快速保存模式',
      buttons: [
        { text: '关闭', color: this.quickSaveMode === 0 ? '#007DFF' : '#333333' },
        { text: '收藏', color: this.quickSaveMode === 1 ? '#007DFF' : '#333333' },
        { text: '开启', color: this.quickSaveMode === 2 ? '#007DFF' : '#333333' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      this.quickSaveMode = result.index;
      this.settingsService.setQuickSaveMode(this.quickSaveMode);
      promptAction.showToast({ message: '快速保存已设置为: ' + this.settingsService.getQuickSaveModeDisplayName(this.quickSaveMode) });
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'SettingsTab', `QuickSave picker error: ${err.message}`);
    });
  }

  // 切换动画
  private toggleAnimation(): void {
    this.animationEnabled = !this.animationEnabled;
    this.settingsService.setAnimationEnabled(this.animationEnabled);
    promptAction.showToast({ message: this.animationEnabled ? '动画已开启' : '动画已关闭' });
  }

  // 切换加密
  private toggleEncryption(): void {
    this.encryptionEnabled = !this.encryptionEnabled;
    this.settingsService.setEncryptionEnabled(this.encryptionEnabled);
    promptAction.showToast({ message: this.encryptionEnabled ? '加密已开启' : '加密已关闭' });
  }

  // 选择保存目录
  private selectSaveDir(): void {
    // HarmonyOS 暂不支持文件夹选择器，使用预设目录
    promptAction.showDialog({
      title: '选择保存目录',
      buttons: [
        { text: '下载', color: this.saveDir === '下载' ? '#007DFF' : '#333333' },
        { text: '图片', color: this.saveDir === '图片' ? '#007DFF' : '#333333' },
        { text: '文档', color: this.saveDir === '文档' ? '#007DFF' : '#333333' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      const dirs: string[] = ['下载', '图片', '文档'];
      this.saveDir = dirs[result.index];
      this.settingsService.setSaveDir(this.saveDir);
      promptAction.showToast({ message: '保存目录已设置为: ' + this.saveDir });
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'SettingsTab', `SaveDir picker error: ${err.message}`);
    });
  }

  // 显示别名输入弹窗
  private showAliasInputDialog() {
    this.tempAliasName = this.aliasName;
    this.showAliasDialog = true;
  }

  // 显示端口输入弹窗
  private showPortInputDialog() {
    this.tempPort = this.port.toString();
    this.showPortDialog = true;
  }

  @Builder SettingsSection(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor('#007DFF')
        .fontWeight(FontWeight.Medium)
        .margin({ left: 32, bottom: 10 })
      
      Column() {
        ForEach(items, (item: SettingsItem, index: number) => {
          this.SettingsRow(item.label, item.value, item.isToggle, item.isOn, item.onClick)
          if (index < items.length - 1) {
            Divider()
              .color('#EEEEEE')
              .strokeWidth(0.5)
              .margin({ left: 16, right: 16 })
          }
        })
      }
      .backgroundColor(Color.White)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
    .margin({ bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder SettingsRow(label: string, value: string, isToggle?: boolean, isOn?: boolean, onClick?: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#111111')
      
      Blank()
      
      if (isToggle) {
        Toggle({ type: ToggleType.Switch, isOn: isOn ?? true })
          .selectedColor('#007DFF')
          .onChange((isOn: boolean) => {
            if (onClick) onClick();
          })
      } else {
        Row() {
          Text(value)
            .fontSize(14)
            .fontColor(Color.Gray)
          // 右箭头图标
          Path()
            .width(12)
            .height(20)
            .commands('M2 2L10 10L2 18')
            .stroke('#999999')
            .strokeWidth(2)
            .fill(Color.Transparent)
            .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      if (!isToggle && onClick) onClick();
    })
  }
}

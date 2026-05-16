import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import { SettingsService, AppSettings } from '../services/SettingsService';
import { SelectPickerDialog, SelectOption } from './SelectPickerDialog';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { I18nManager, t } from '../utils/I18nManager';

// 获取全局上下文
let context = getContext(this) as common.UIAbilityContext;

// 设置项接口
interface SettingsItem {
  label: string;
  value: string;
  key: string;
  isToggle?: boolean;
  isOn?: boolean;
  onClick?: () => void;
}

// 主题选项
const getThemeOptions = (): SelectOption[] => [
  { value: 'system', label: t('theme_system') },
  { value: 'light', label: t('theme_light') },
  { value: 'dark', label: t('theme_dark') },
  { value: 'black', label: t('theme_black') }
];

// 色彩选项
const getColorOptions = (): SelectOption[] => [
  { value: 'blue', label: t('color_blue') },
  { value: 'green', label: t('color_green') },
  { value: 'yellow', label: t('color_yellow') },
  { value: 'orange', label: t('color_orange') },
  { value: 'red', label: t('color_red') },
  { value: 'pink', label: t('color_pink') },
  { value: 'purple', label: t('color_purple') },
  { value: 'teal', label: t('color_teal') }
];

// 语言选项
const getLanguageOptions = (): SelectOption[] => [
  { value: 'system', label: t('language_system') },
  { value: 'zh', label: '中文' },
  { value: 'en', label: 'English' }
];

// 快速保存选项
const getQuickSaveOptions = (): SelectOption[] => [
  { value: '0', label: t('quick_save_off') },
  { value: '1', label: t('quick_save_fav') },
  { value: '2', label: t('quick_save_on') }
];

// 保存目录选项
const getSaveDirOptions = (): SelectOption[] => [
  { value: '下载', label: '下载' },
  { value: '图片', label: '图片' },
  { value: '文档', label: '文档' }
];

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
  @State colorTheme: string = 'blue';
  @State language: string = 'system';
  @State encryptionEnabled: boolean = true;
  @Link saveDir: string;
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }
  
  // 弹窗状态
  @State showAliasDialog: boolean = false;
  @State showPortDialog: boolean = false;
  @State tempAliasName: string = '';
  @State tempPort: string = '';
  
  // 选择弹窗状态
  @State showThemePicker: boolean = false;
  @State showLanguagePicker: boolean = false;
  @State showQuickSavePicker: boolean = false;
  @State showSaveDirPicker: boolean = false;
  
  // 主题弹窗控制器
  private themeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('theme_title'),
      options: getThemeOptions(),
      currentValue: this.theme,
      onSelected: (value: string) => this.onThemeSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 色彩弹窗控制器
  private colorThemeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('color_title'),
      options: getColorOptions(),
      currentValue: this.colorTheme,
      onSelected: (value: string) => this.onColorThemeSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 语言弹窗控制器
  private languageDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('language_title'),
      options: getLanguageOptions(),
      currentValue: this.language,
      onSelected: (value: string) => this.onLanguageSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 快速保存弹窗控制器
  private quickSaveDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('quick_save'),
      options: getQuickSaveOptions(),
      currentValue: this.quickSaveMode.toString(),
      onSelected: (value: string) => this.onQuickSaveSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 保存目录弹窗控制器
  private saveDirDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('save_dir'),
      options: getSaveDirOptions(),
      currentValue: this.saveDir,
      onSelected: (value: string) => this.onSaveDirSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  aboutToAppear(): void {
    // 获取 context
    this.context = getContext(this) as common.UIAbilityContext;
    // 初始化并加载保存的设置
    this.initAndLoadSettings();
  }
  
  private async initAndLoadSettings(): Promise<void> {
    await this.settingsService.init(this.context!);
    this.loadSettings();
  }
  
  // 加载设置
  private loadSettings(): void {
    this.settingsService.getSettings().then((settings: AppSettings) => {
      this.theme = settings.theme;
      this.colorTheme = settings.colorTheme;
      this.language = settings.language;
      this.animationEnabled = settings.animationEnabled;
      this.quickSaveMode = settings.quickSaveMode;
      this.saveDir = settings.saveDir;
      this.port = settings.port;
      this.encryptionEnabled = settings.encryptionEnabled;
      this.aliasName = settings.aliasName;
      
      // 应用主题
      this.applyTheme(this.theme);
      this.applyColorTheme(this.colorTheme);
    }).catch((err: Error) => {
      hilog.error(0x0000, 'SettingsTab', `Failed to load settings: ${err.message}`);
    });
  }
  
  // 应用主题
  private applyTheme(theme: string): void {
    // 存储到全局状态，供其他组件使用
    AppStorage.setOrCreate('appTheme', theme);
    // 触发主题版本更新，确保 UI 刷新
    ThemeManager.incrementThemeVersion();
    hilog.info(0x0000, 'SettingsTab', `Theme applied: ${theme}`);
  }

  // 应用色彩
  private applyColorTheme(color: string): void {
    AppStorage.setOrCreate('appColorTheme', color);
    // 触发主题版本更新，确保 UI 刷新
    ThemeManager.incrementThemeVersion();
    hilog.info(0x0000, 'SettingsTab', `Color Theme applied: ${color}`);
  }
  
  // 应用语言
  private applyLanguage(language: string): void {
    // 存储到全局状态，供其他组件使用
    AppStorage.setOrCreate('appLanguage', language);
    // 触发语言版本更新，确保 UI 刷新
    I18nManager.incrementLanguageVersion();
    hilog.info(0x0000, 'SettingsTab', `Language applied: ${language}`);
  }
  
  // 主题选择回调
  private onThemeSelected(value: string): void {
    this.theme = value;
    this.settingsService.setTheme(value);
    this.applyTheme(value);
    const label = getThemeOptions().find(o => o.value === value)?.label || value;
    promptAction.showToast({ message: '主题已切换为: ' + label });
  }
  
  // 色彩选择回调
  private onColorThemeSelected(value: string): void {
    this.colorTheme = value;
    this.settingsService.setColorTheme(value);
    this.applyColorTheme(value);
    const label = getColorOptions().find(o => o.value === value)?.label || value;
    promptAction.showToast({ message: '色彩已切换为: ' + label });
  }
  
  // 语言选择回调
  private onLanguageSelected(value: string): void {
    this.language = value;
    this.settingsService.setLanguage(value);
    this.applyLanguage(value);
    const label = getLanguageOptions().find(o => o.value === value)?.label || value;
    promptAction.showToast({ message: '语言已切换为: ' + label });
  }
  
  // 快速保存选择回调
  private onQuickSaveSelected(value: string): void {
    this.quickSaveMode = parseInt(value);
    this.settingsService.setQuickSaveMode(this.quickSaveMode);
    const label = getQuickSaveOptions().find(o => o.value === value)?.label || value;
    promptAction.showToast({ message: '快速保存已设置为: ' + label });
  }
  
  // 保存目录选择回调
  private onSaveDirSelected(value: string): void {
    this.saveDir = value;
    this.settingsService.setSaveDir(value);
    promptAction.showToast({ message: '保存目录已设置为: ' + value });
  }

  build() {
    Scroll() {
      Column() {
        Text(t('tab_settings'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary'))
          .width('100%')
          .padding({ left: 32, top: 20, bottom: 24 })

        this.SettingsSection(t('general_settings'), [
          { 
            label: t('theme_title'), 
            value: getThemeOptions().find(o => o.value === this.theme)?.label || this.theme,
            key: 'theme',
            onClick: (): void => { this.themeDialogController.open(); }
          },
          { 
            label: t('color_title'), 
            value: getColorOptions().find(o => o.value === this.colorTheme)?.label || this.colorTheme,
            key: 'color',
            onClick: (): void => { this.colorThemeDialogController.open(); }
          },
          { 
            label: t('language_title'), 
            value: getLanguageOptions().find(o => o.value === this.language)?.label || this.language,
            key: 'lang',
            onClick: (): void => { this.languageDialogController.open(); }
          },
          { 
            label: t('animation_title'), 
            value: '', 
            isToggle: true, 
            isOn: this.animationEnabled,
            key: 'anim',
            onClick: (): void => this.toggleAnimation()
          }
        ])

        this.SettingsSection(t('receive_settings'), [
          { 
            label: t('quick_save'), 
            value: getQuickSaveOptions().find(o => o.value === this.quickSaveMode.toString())?.label || this.quickSaveMode.toString(),
            key: 'quickSave',
            onClick: (): void => { this.quickSaveDialogController.open(); }
          },
          { 
            label: t('save_dir'), 
            value: this.saveDir,
            key: 'dir',
            onClick: (): void => { this.saveDirDialogController.open(); }
          }
        ])

        this.SettingsSection(t('network_settings'), [
          { 
            label: t('device_alias'), 
            value: this.aliasName, 
            key: 'alias',
            onClick: (): void => this.showAliasInputDialog()
          },
          { 
            label: t('device_port'), 
            value: this.port.toString(),
            key: 'port',
            onClick: (): void => this.showPortInputDialog()
          }
        ])

        this.SettingsSection(t('about_title'), [
          { 
            label: t('privacy_policy'), 
            value: '',
            key: 'privacy',
            onClick: (): void => this.openPrivacyPolicy()
          },
          { 
            label: t('third_party'), 
            value: '',
            key: 'third',
            onClick: (): void => { router.pushUrl({ url: 'pages/ThirdPartyLicenses' }); }
          }
        ])

        // 关于
        Column() {
          Image($r('app.media.app_icon'))
            .width(80).height(80)
            .borderRadius(16)
            .margin({ top: 20, bottom: 12 })
          Text(t('app_name'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(gc('text_primary'))
          Text('版本: 1.0.0')
            .fontSize(14)
            .fontColor(gc('text_secondary'))
            .margin({ top: 4 })
          Text(t('copy_right'))
            .fontSize(12)
            .fontColor(gc('text_tertiary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 64 })
      }
      .width('100%')
    }
    .key(`settings_scroll_${this.refreshKey}`)
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary'))
    .bindSheet(this.showAliasDialog, this.AliasInputDialog(), {
      height: 200,
      backgroundColor: gc('bg_secondary'),
      dragBar: true
    })
    .bindSheet(this.showPortDialog, this.PortInputDialog(), {
      height: 200,
      backgroundColor: gc('bg_secondary'),
      dragBar: true
    })
  }

  // 别名输入弹窗
  @Builder AliasInputDialog() {
    Column() {
      Text(t('change_alias'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary'))
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempAliasName, placeholder: t('input_alias') })
        .width('90%')
        .height(48)
        .onChange((value: string) => {
          this.tempAliasName = value;
        })
      
      Row() {
        Button(t('cancel'))
          .width('40%')
          .backgroundColor(gc('bg_primary'))
          .fontColor(gc('text_primary'))
          .onClick(() => {
            this.showAliasDialog = false;
          })
        
        Button(t('confirm'))
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
      Text(t('change_port'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary'))
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempPort, placeholder: t('input_port') })
        .width('90%')
        .height(48)
        .type(InputType.Number)
        .onChange((value: string) => {
          this.tempPort = value;
        })
      
      Row() {
        Button(t('cancel'))
          .width('40%')
          .backgroundColor(gc('bg_primary'))
          .fontColor(gc('text_primary'))
          .onClick(() => {
            this.showPortDialog = false;
          })
        
        Button(t('confirm'))
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

  // 切换动画
  private toggleAnimation(): void {
    this.animationEnabled = !this.animationEnabled;
    this.settingsService.setAnimationEnabled(this.animationEnabled);
    promptAction.showToast({ message: this.animationEnabled ? '动画已开启' : '动画已关闭' });
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

  // 打开隐私政策
  private openPrivacyPolicy() {
    // 使用系统浏览器打开隐私政策页面
    const privacyUrl = 'https://github.com/never88gone/localsend_never88gone/blob/main/Privacy.md';
    context.openLink(privacyUrl).catch((err: Error) => {
      hilog.error(0x0000, 'SettingsTab', 'Failed to open privacy policy: ' + err.message);
      promptAction.showToast({ message: '无法打开浏览器' });
    });
  }

  @Builder SettingsSection(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor(gc('accent'))
        .fontWeight(FontWeight.Medium)
        .margin({ left: 32, bottom: 10 })
      
      Column() {
        ForEach(items, (item: SettingsItem, index: number) => {
          this.SettingsRow(item.label, item.value, item.isToggle, item.isOn, item.onClick)
          if (index < items.length - 1) {
            Divider()
              .color(gc('divider'))
              .strokeWidth(0.5)
              .margin({ left: 16, right: 16 })
          }
        })
      }
      .backgroundColor(gc('bg_secondary'))
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
        .fontColor(gc('text_primary'))
      
      Blank()
      
      if (isToggle) {
        Toggle({ type: ToggleType.Switch, isOn: isOn ?? true })
          .selectedColor(gc('accent'))
          .onChange((isOn: boolean) => {
            if (onClick) onClick();
          })
      } else {
        Row() {
          Text(value)
            .fontSize(14)
            .fontColor(gc('text_secondary'))
          // 右箭头图标
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([gc('text_tertiary')])
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

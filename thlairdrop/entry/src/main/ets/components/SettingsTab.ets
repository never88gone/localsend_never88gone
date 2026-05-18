import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import { SettingsService } from '../services/SettingsService';
import { SelectPickerDialog, SelectOption } from './SelectPickerDialog';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { I18nManager, t } from '../utils/I18nManager';

// 色彩选项
const getColorOptions = (lv?: number): SelectOption[] => [
  { value: 'blue', label: t('color_blue', lv) },
  { value: 'green', label: t('color_green', lv) },
  { value: 'yellow', label: t('color_yellow', lv) },
  { value: 'orange', label: t('color_orange', lv) },
  { value: 'red', label: t('color_red', lv) },
  { value: 'pink', label: t('color_pink', lv) },
  { value: 'purple', label: t('color_purple', lv) },
  { value: 'teal', label: t('color_teal', lv) }
];

// 语言选项
const getLanguageOptions = (lv?: number): SelectOption[] => [
  { value: 'system', label: t('language_system', lv) },
  { value: 'zh', label: '中文' },
  { value: 'en', label: 'English' }
];

// 快速保存选项
const getQuickSaveOptions = (lv?: number): SelectOption[] => [
  { value: '0', label: t('quick_save_off', lv) },
  { value: '1', label: t('quick_save_fav', lv) },
  { value: '2', label: t('quick_save_on', lv) }
];

// 保存目录选项
const getSaveDirOptions = (lv?: number): SelectOption[] => [
  { value: '下载', label: t('save_dir_download', lv) },
  { value: '图片', label: t('save_dir_pictures', lv) },
  { value: '文档', label: t('save_dir_documents', lv) }
];

@Component
export struct SettingsTab {
  @Link aliasName: string;
  @Link quickSaveMode: number;
  @Link animationEnabled: boolean;
  @Link port: number;
  @Link saveDir: string;
  
  // 设置服务 (由 Index.ets 初始化)
  private settingsService: SettingsService = SettingsService.getInstance();
  private context: common.UIAbilityContext | null = null;
  
  // 设置状态 (通过 Index.ets 同步)
  @StorageLink('appTheme') theme: string = 'system';
  @StorageLink('appColorTheme') colorTheme: string = 'blue';
  @StorageLink('appLanguage') language: string = 'system';
  @State encryptionEnabled: boolean = true;
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
  
  // 色彩弹窗控制器
  private colorThemeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('color_title', this.languageVersion),
      options: getColorOptions(this.languageVersion),
      currentValue: this.colorTheme,
      onSelected: (value: string): void => this.onColorThemeSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 语言弹窗控制器
  private languageDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('language_title', this.languageVersion),
      options: getLanguageOptions(this.languageVersion),
      currentValue: this.language,
      onSelected: (value: string): void => this.onLanguageSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 快速保存弹窗控制器
  private quickSaveDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('quick_save', this.languageVersion),
      options: getQuickSaveOptions(this.languageVersion),
      currentValue: this.quickSaveMode.toString(),
      onSelected: (value: string): void => this.onQuickSaveSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  // 保存目录弹窗控制器
  private saveDirDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      title: t('save_dir', this.languageVersion),
      options: getSaveDirOptions(this.languageVersion),
      currentValue: this.saveDir,
      onSelected: (value: string): void => this.onSaveDirSelected(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  
  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
  }
  
  // 应用主题变化并广播
  private applyTheme(theme: string): void {
    AppStorage.setOrCreate('appTheme', theme);
    ThemeManager.incrementThemeVersion();
  }

  private applyColorTheme(color: string): void {
    AppStorage.setOrCreate('appColorTheme', color);
    ThemeManager.incrementThemeVersion();
  }
  
  private applyLanguage(language: string): void {
    AppStorage.setOrCreate('appLanguage', language);
    I18nManager.incrementLanguageVersion();
  }
  
  // 色彩选择回调
  private onColorThemeSelected(value: string): void {
    this.colorTheme = value;
    this.settingsService.setColorTheme(value);
    this.applyColorTheme(value);
    const options = getColorOptions(this.languageVersion);
    const option = options.find((o: SelectOption): boolean => o.value === value);
    const label = option ? option.label : value;
    promptAction.showToast({ message: t('color_title', this.languageVersion) + ': ' + label });
  }
  
  // 语言选择回调
  private onLanguageSelected(value: string): void {
    this.language = value;
    this.settingsService.setLanguage(value);
    this.applyLanguage(value);
    const options = getLanguageOptions(this.languageVersion);
    const option = options.find((o: SelectOption): boolean => o.value === value);
    const label = option ? option.label : value;
    promptAction.showToast({ message: t('language_title', this.languageVersion) + ': ' + label });
  }
  
  // 快速保存选择回调
  private onQuickSaveSelected(value: string): void {
    this.quickSaveMode = parseInt(value);
    this.settingsService.setQuickSaveMode(this.quickSaveMode);
    const options = getQuickSaveOptions(this.languageVersion);
    const option = options.find((o: SelectOption): boolean => o.value === value);
    const label = option ? option.label : value;
    promptAction.showToast({ message: t('quick_save', this.languageVersion) + ': ' + label });
  }
  
  // 保存目录选择回调
  private onSaveDirSelected(value: string): void {
    this.saveDir = value;
    this.settingsService.setSaveDir(value);
    promptAction.showToast({ message: t('save_dir', this.languageVersion) + ': ' + t(value, this.languageVersion) });
  }

  build() {
    Scroll() {
      Column() {
        Text(t('tab_settings', this.languageVersion))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary', this.themeVersion))
          .width('100%')
          .padding({ left: 32, top: 20, bottom: 24 })

        // 常规设置
        Column() {
          Text(t('general_settings', this.languageVersion))
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .width('100%')
            .padding({ left: 32, bottom: 8 })

          Column() {
            SettingsRowComponent({
              label: t('color_title', this.languageVersion),
              value: (getColorOptions(this.languageVersion).find((o: SelectOption): boolean => o.value === this.colorTheme)?.label || this.colorTheme) as string,
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.colorThemeDialogController.open(); }
            })
            SettingsRowComponent({
              label: t('language_title', this.languageVersion),
              value: (getLanguageOptions(this.languageVersion).find((o: SelectOption): boolean => o.value === this.language)?.label || this.language) as string,
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.languageDialogController.open(); }
            })
            SettingsRowComponent({
              label: t('animation_title', this.languageVersion),
              isToggle: true,
              isOn: this.animationEnabled,
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.toggleAnimation(); }
            })
          }
          .width('90%')
          .backgroundColor(gc('bg_secondary', this.themeVersion))
          .borderRadius(16)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
        }
        .width('100%')
        .margin({ bottom: 24 })

        // 接收设置
        Column() {
          Text(t('receive_settings', this.languageVersion))
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .width('100%')
            .padding({ left: 32, bottom: 8 })

          Column() {
            SettingsRowComponent({
              label: t('quick_save', this.languageVersion),
              value: (getQuickSaveOptions(this.languageVersion).find((o: SelectOption): boolean => o.value === this.quickSaveMode.toString())?.label || this.quickSaveMode.toString()) as string,
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.quickSaveDialogController.open(); }
            })
            SettingsRowComponent({
              label: t('save_dir', this.languageVersion),
              value: t(this.saveDir, this.languageVersion),
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.saveDirDialogController.open(); }
            })
          }
          .width('90%')
          .backgroundColor(gc('bg_secondary', this.themeVersion))
          .borderRadius(16)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
        }
        .width('100%')
        .margin({ bottom: 24 })

        // 网络设置
        Column() {
          Text(t('network_settings', this.languageVersion))
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .width('100%')
            .padding({ left: 32, bottom: 8 })

          Column() {
            SettingsRowComponent({
              label: t('device_alias', this.languageVersion),
              value: this.aliasName,
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.showAliasInputDialog(); }
            })
            SettingsRowComponent({
              label: t('device_port', this.languageVersion),
              value: this.port.toString(),
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.showPortInputDialog(); }
            })
          }
          .width('90%')
          .backgroundColor(gc('bg_secondary', this.themeVersion))
          .borderRadius(16)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
        }
        .width('100%')
        .margin({ bottom: 24 })

        // 关于
        Column() {
          Text(t('about_title', this.languageVersion))
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .width('100%')
            .padding({ left: 32, bottom: 8 })

          Column() {
            SettingsRowComponent({
              label: t('privacy_policy', this.languageVersion),
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { this.openPrivacyPolicy(); }
            })
            SettingsRowComponent({
              label: t('third_party', this.languageVersion),
              themeVersion: this.themeVersion,
              languageVersion: this.languageVersion,
              onItemClick: (): void => { router.pushUrl({ url: 'pages/ThirdPartyLicenses' }); }
            })
          }
          .width('90%')
          .backgroundColor(gc('bg_secondary', this.themeVersion))
          .borderRadius(16)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 4 })
        }
        .width('100%')
        .margin({ bottom: 24 })

        // 版本信息
        Column() {
          Image($r('app.media.app_icon'))
            .width(80).height(80)
            .borderRadius(16)
            .margin({ top: 20, bottom: 12 })
          Text(t('app_name', this.languageVersion))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(gc('text_primary', this.themeVersion))
          Text('v1.0.0')
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .margin({ top: 4 })
          Text(t('copy_right', this.languageVersion))
            .fontSize(12)
            .fontColor(gc('text_tertiary', this.themeVersion))
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ bottom: 40 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .key(`settings_scroll_${this.refreshKey}`)
    .backgroundColor(gc('bg_primary', this.themeVersion))
    .bindSheet(this.showAliasDialog, this.AliasInputDialog(), {
      height: 200,
      backgroundColor: gc('bg_secondary', this.themeVersion),
      dragBar: true
    })
    .bindSheet(this.showPortDialog, this.PortInputDialog(), {
      height: 200,
      backgroundColor: gc('bg_secondary', this.themeVersion),
      dragBar: true
    })
  }

  // 别名输入弹窗
  @Builder AliasInputDialog() {
    Column() {
      Text(t('change_alias', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempAliasName, placeholder: t('input_alias', this.languageVersion) })
        .width('90%')
        .height(48)
        .onChange((value: string): void => {
          this.tempAliasName = value;
        })
      
      Row() {
        Button(t('cancel', this.languageVersion))
          .width('40%')
          .backgroundColor(gc('bg_primary', this.themeVersion))
          .fontColor(gc('text_primary', this.themeVersion))
          .onClick((): void => {
            this.showAliasDialog = false;
          })
        
        Button(t('confirm', this.languageVersion))
          .width('40%')
          .onClick((): void => {
            if (this.tempAliasName.trim()) {
              this.aliasName = this.tempAliasName.trim();
              this.settingsService.setAliasName(this.aliasName);
              promptAction.showToast({ message: t('change_alias', this.languageVersion) + ': ' + this.aliasName });
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
      Text(t('change_port', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 16, bottom: 16 })
      
      TextInput({ text: this.tempPort, placeholder: t('input_port', this.languageVersion) })
        .width('90%')
        .height(48)
        .type(InputType.Number)
        .onChange((value: string): void => {
          this.tempPort = value;
        })
      
      Row() {
        Button(t('cancel', this.languageVersion))
          .width('40%')
          .backgroundColor(gc('bg_primary', this.themeVersion))
          .fontColor(gc('text_primary', this.themeVersion))
          .onClick((): void => {
            this.showPortDialog = false;
          })
        
        Button(t('confirm', this.languageVersion))
          .width('40%')
          .onClick((): void => {
            const newPort = parseInt(this.tempPort);
            if (newPort >= 1024 && newPort <= 65535) {
              this.port = newPort;
              this.settingsService.setPort(this.port);
              promptAction.showToast({ message: t('change_port', this.languageVersion) + ': ' + this.port });
            } else {
              promptAction.showToast({ message: 'Error' });
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
    promptAction.showToast({ message: t('animation_title', this.languageVersion) });
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
    this.context?.openLink(privacyUrl).catch((err: Error) => {
      hilog.error(0x0000, 'SettingsTab', 'Failed to open privacy policy: ' + err.message);
      promptAction.showToast({ message: 'Error' });
    });
  }
}

/**
 * 设置行组件
 */
@Component
struct SettingsRowComponent {
  @Prop label: string;
  @Prop value: string = '';
  @Prop isToggle: boolean = false;
  @Prop isOn: boolean = false;
  @Prop themeVersion: number;
  @Prop languageVersion: number;
  onItemClick: () => void = (): void => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(16)
        .fontColor(gc('text_primary', this.themeVersion))
        .layoutWeight(1)

      if (this.isToggle) {
        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .selectedColor(gc('accent', this.themeVersion))
          .onChange((): void => this.onItemClick())
      } else {
        Row() {
          Text(this.value)
            .fontSize(14)
            .fontColor(gc('text_secondary', this.themeVersion))
            .margin({ right: 4 })
          
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([gc('text_tertiary', this.themeVersion)])
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .onClick((): void => {
      if (!this.isToggle) {
        this.onItemClick();
      }
    })
  }
}

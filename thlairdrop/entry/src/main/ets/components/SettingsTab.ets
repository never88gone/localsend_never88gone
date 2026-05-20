import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import { SettingsService } from '../services/SettingsService';
import { SelectPickerDialog, SelectOption } from './SelectPickerDialog';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { I18nManager, t } from '../utils/I18nManager';
import { BuildInfo } from '../utils/BuildInfo';

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
  @StorageLink('appPinCode') pinCode: string = '';
  @State encryptionEnabled: boolean = true;
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }
  
  // 弹窗状态
  @State tempAliasName: string = '';
  @State tempPort: string = '';
  @State tempPinCode: string = '';

  private aliasDialogController: CustomDialogController | null = new CustomDialogController({
    builder: AliasInputDialogComponent({
      tempAliasName: $tempAliasName,
      onConfirm: () => {
        if (this.tempAliasName.trim()) {
          this.aliasName = this.tempAliasName.trim();
          this.settingsService.setAliasName(this.aliasName);
          promptAction.showToast({ message: t('change_alias', this.languageVersion) + ': ' + this.aliasName });
        }
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  private portDialogController: CustomDialogController | null = new CustomDialogController({
    builder: PortInputDialogComponent({
      tempPort: $tempPort,
      onConfirm: () => {
        const newPort = parseInt(this.tempPort);
        if (newPort >= 1024 && newPort <= 65535) {
          this.port = newPort;
          this.settingsService.setPort(this.port);
          promptAction.showToast({ message: t('change_port', this.languageVersion) + ': ' + this.port });
        } else {
          promptAction.showToast({ message: 'Error' });
        }
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  private pinCodeDialogController: CustomDialogController | null = new CustomDialogController({
    builder: PinCodeInputDialogComponent({
      tempPinCode: $tempPinCode,
      onConfirm: () => {
        this.pinCode = this.tempPinCode.trim();
        this.settingsService.setPinCode(this.pinCode);
        promptAction.showToast({ message: t('change_pin_code', this.languageVersion) + ': ' + (this.pinCode ? this.pinCode : t('pin_code_disabled', this.languageVersion)) });
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });
  
  // 色彩弹窗控制器
  private colorThemeDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      dialogType: 'color',
      currentValue: this.colorTheme,
      onSelected: (value: string): void => this.onColorThemeSelected(value)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });
  
  // 语言弹窗控制器
  private languageDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      dialogType: 'language',
      currentValue: this.language,
      onSelected: (value: string): void => this.onLanguageSelected(value)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });
  
  // 快速保存弹窗控制器
  private quickSaveDialogController: CustomDialogController = new CustomDialogController({
    builder: SelectPickerDialog({
      dialogType: 'quick_save',
      currentValue: this.quickSaveMode.toString(),
      onSelected: (value: string): void => this.onQuickSaveSelected(value)
    }),
    autoCancel: true,
    customStyle: true,
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
  
  build() {
    Column() {
      // 顶部固定标题
      Row() {
        Text(t('tab_settings', this.languageVersion))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary', this.themeVersion))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      // 可滚动的设置列表
      Scroll() {
        Column() {
          // 常规设置
          Column() {
            Text(t('general_settings', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .width('100%')
              .padding({ left: 0, bottom: 8 })

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
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 接收设置
          Column() {
            Text(t('receive_settings', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .width('100%')
              .padding({ left: 0, bottom: 8 })

            Column() {
              SettingsRowComponent({
                label: t('quick_save', this.languageVersion),
                value: (getQuickSaveOptions(this.languageVersion).find((o: SelectOption): boolean => o.value === this.quickSaveMode.toString())?.label || this.quickSaveMode.toString()) as string,
                themeVersion: this.themeVersion,
                languageVersion: this.languageVersion,
                onItemClick: (): void => { this.quickSaveDialogController.open(); }
              })
            }
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 设备设置
          Column() {
            Text(t('device_settings', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .width('100%')
              .padding({ left: 0, bottom: 8 })

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
              SettingsRowComponent({
                label: t('pin_code', this.languageVersion),
                value: this.pinCode || t('pin_code_disabled', this.languageVersion),
                themeVersion: this.themeVersion,
                languageVersion: this.languageVersion,
                onItemClick: (): void => { this.showPinCodeInputDialog(); }
              })
            }
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 隐私与安全
          Column() {
            Text(t('privacy_security', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .width('100%')
              .padding({ left: 0, bottom: 8 })

            Column() {
              SettingsRowComponent({
                label: t('privacy_policy', this.languageVersion),
                themeVersion: this.themeVersion,
                languageVersion: this.languageVersion,
                onItemClick: (): void => { router.pushUrl({ url: 'pages/PrivacyPolicy' }); }
              })
              SettingsRowComponent({
                label: t('third_party', this.languageVersion),
                themeVersion: this.themeVersion,
                languageVersion: this.languageVersion,
                onItemClick: (): void => { router.pushUrl({ url: 'pages/ThirdPartyLicenses' }); }
              })
            }
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 联系与社区
          Column() {
            Text(t('contact_community', this.languageVersion))
              .fontSize(14)
              .fontColor(gc('text_secondary', this.themeVersion))
              .width('100%')
              .padding({ left: 0, bottom: 8 })

            Column() {
              SettingsRowComponent({
                label: t('contact_community', this.languageVersion),
                themeVersion: this.themeVersion,
                languageVersion: this.languageVersion,
                onItemClick: (): void => { router.pushUrl({ url: 'pages/ContactCommunity' }); }
              })
            }
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
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
            Text(`v${BuildInfo.VERSION_NAME} (${BuildInfo.BUILD_NUMBER})`)
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
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .key(`settings_scroll_${this.refreshKey}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary', this.themeVersion))
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
    if (this.aliasDialogController) {
      this.aliasDialogController.open();
    }
  }

  // 显示端口输入弹窗
  private showPortInputDialog() {
    this.tempPort = this.port.toString();
    if (this.portDialogController) {
      this.portDialogController.open();
    }
  }

  // 显示 PIN 码输入弹窗
  private showPinCodeInputDialog() {
    this.tempPinCode = this.pinCode;
    if (this.pinCodeDialogController) {
      this.pinCodeDialogController.open();
    }
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
  @State isPressed: boolean = false;

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
    .backgroundColor(this.isPressed && !this.isToggle ? gc('accent_bg', this.themeVersion) : Color.Transparent)
    .onTouch((event: TouchEvent) => {
      if (!this.isToggle) {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      }
    })
    .onClick((): void => {
      if (!this.isToggle) {
        this.onItemClick();
      }
    })
  }
}

/**
 * 别名输入弹窗组件
 */
@CustomDialog
struct AliasInputDialogComponent {
  controller: CustomDialogController;
  @Link tempAliasName: string;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};

  @StorageProp('themeVersion') themeVersion: number = 0;
  @StorageProp('languageVersion') languageVersion: number = 0;

  build() {
    Column() {
      Text(t('change_alias', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 8, bottom: 16 })
      
      TextInput({ text: this.tempAliasName, placeholder: t('input_alias', this.languageVersion) })
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor(gc('text_primary', this.themeVersion))
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .placeholderColor(gc('text_tertiary', this.themeVersion))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.tempAliasName = value;
        })
        .margin({ bottom: 20 })
      
      Row() {
        Button(t('cancel', this.languageVersion))
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(gc('text_secondary', this.themeVersion))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: gc('divider', this.themeVersion) })
          .borderRadius(12)
          .height(42)
          .onClick((): void => {
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
          .onClick((): void => {
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

/**
 * 端口输入弹窗组件
 */
@CustomDialog
struct PortInputDialogComponent {
  controller: CustomDialogController;
  @Link tempPort: string;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};

  @StorageProp('themeVersion') themeVersion: number = 0;
  @StorageProp('languageVersion') languageVersion: number = 0;

  build() {
    Column() {
      Text(t('change_port', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 8, bottom: 16 })
      
      TextInput({ text: this.tempPort, placeholder: t('input_port', this.languageVersion) })
        .width('100%')
        .height(48)
        .type(InputType.Number)
        .fontSize(15)
        .fontColor(gc('text_primary', this.themeVersion))
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .placeholderColor(gc('text_tertiary', this.themeVersion))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.tempPort = value;
        })
        .margin({ bottom: 20 })
      
      Row() {
        Button(t('cancel', this.languageVersion))
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(gc('text_secondary', this.themeVersion))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: gc('divider', this.themeVersion) })
          .borderRadius(12)
          .height(42)
          .onClick((): void => {
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
          .onClick((): void => {
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

/**
 * PIN 码输入弹窗组件
 */
@CustomDialog
struct PinCodeInputDialogComponent {
  controller: CustomDialogController;
  @Link tempPinCode: string;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};

  @StorageProp('themeVersion') themeVersion: number = 0;
  @StorageProp('languageVersion') languageVersion: number = 0;

  build() {
    Column() {
      Text(t('change_pin_code', this.languageVersion))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(gc('text_primary', this.themeVersion))
        .margin({ top: 8, bottom: 12 })
      
      TextInput({ text: this.tempPinCode, placeholder: t('input_pin_code', this.languageVersion) })
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor(gc('text_primary', this.themeVersion))
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .placeholderColor(gc('text_tertiary', this.themeVersion))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.tempPinCode = value;
        })
      
      Button(t('random_generate', this.languageVersion))
        .fontSize(14)
        .fontColor(gc('accent', this.themeVersion))
        .backgroundColor(Color.Transparent)
        .margin({ top: 8, bottom: 16 })
        .onClick((): void => {
          const randomPin = Math.floor(1000 + Math.random() * 9000).toString();
          this.tempPinCode = randomPin;
        })
      
      Row() {
        Button(t('cancel', this.languageVersion))
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(gc('text_secondary', this.themeVersion))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: gc('divider', this.themeVersion) })
          .borderRadius(12)
          .height(42)
          .onClick((): void => {
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
          .onClick((): void => {
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

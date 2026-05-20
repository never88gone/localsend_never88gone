/**
 * 自定义选择弹窗组件
 * 用于主题、语言等选项选择
 */
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

// 选项接口
export interface SelectOption {
  value: string;     // 选项值
  label: string;     // 显示文本
}

// 选择弹窗控制器
export class SelectPickerController {
  private showDialog: ((show: boolean) => void) | null = null;
  private onSelect: ((value: string) => void) | null = null;

  // 设置回调
  setCallbacks(showDialog: (show: boolean) => void, onSelect: (value: string) => void): void {
    this.showDialog = showDialog;
    this.onSelect = onSelect;
  }

  // 显示弹窗
  show(): void {
    if (this.showDialog) {
      this.showDialog(true);
    }
  }

  // 选择项
  select(value: string): void {
    if (this.onSelect) {
      this.onSelect(value);
    }
  }
}

// 选择弹窗参数
export interface SelectPickerParams {
  title: string;
  options: SelectOption[];
  currentValue: string;
  onSelected: (value: string) => void;
}

/**
 * 选择弹窗组件
 */
@CustomDialog
export struct SelectPickerDialog {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @StorageProp('appLanguage') currentLanguage: string = 'system';
  @StorageProp('languageVersion') languageVersion: number = 0;
  // 弹窗控制器
  controller: CustomDialogController;
  
  // 弹窗参数
  @Prop dialogType: string = '';
  @Prop currentValue: string = '';
  
  // 选择回调
  onSelected: (value: string) => void = (_value: string) => {};

  // 获取颜色值
  getColorHex(value: string): string {
    const colors: Record<string, string> = {
      'blue': '#3B82F6',
      'green': '#22C55E',
      'yellow': '#F59E0B',
      'orange': '#F97316',
      'red': '#EF4444',
      'pink': '#EC4899',
      'purple': '#A855F7',
      'teal': '#14B8A6'
    };
    return colors[value] || '#3B82F6';
  }

  // 判断是否为颜色选项
  isColorTheme(value: string): boolean {
    const colorKeys = ['blue', 'green', 'yellow', 'orange', 'red', 'pink', 'purple', 'teal'];
    return colorKeys.includes(value);
  }

  getTitle(): string {
    const lv = this.languageVersion;
    if (this.dialogType === 'color') return t('color_title', lv);
    if (this.dialogType === 'language') return t('language_title', lv);
    if (this.dialogType === 'quick_save') return t('quick_save', lv);
    if (this.dialogType === 'save_dir') return t('save_dir', lv);
    return t('confirm', lv);
  }

  getOptions(): SelectOption[] {
    const lv = this.languageVersion;
    if (this.dialogType === 'color') {
      return [
        { value: 'blue', label: t('color_blue', lv) },
        { value: 'green', label: t('color_green', lv) },
        { value: 'yellow', label: t('color_yellow', lv) },
        { value: 'orange', label: t('color_orange', lv) },
        { value: 'red', label: t('color_red', lv) },
        { value: 'pink', label: t('color_pink', lv) },
        { value: 'purple', label: t('color_purple', lv) },
        { value: 'teal', label: t('color_teal', lv) }
      ];
    }
    if (this.dialogType === 'language') {
      return [
        { value: 'system', label: t('language_system', lv) },
        { value: 'zh', label: '中文' },
        { value: 'en', label: 'English' }
      ];
    }
    if (this.dialogType === 'quick_save') {
      return [
        { value: '0', label: t('quick_save_off', lv) },
        { value: '1', label: t('quick_save_fav', lv) },
        { value: '2', label: t('quick_save_on', lv) }
      ];
    }
    if (this.dialogType === 'save_dir') {
      return [
        { value: '下载', label: t('save_dir_download', lv) },
        { value: '图片', label: t('save_dir_pictures', lv) },
        { value: '文档', label: t('save_dir_documents', lv) }
      ];
    }
    return [];
  }
  
  build() {
    Column() {
      // 标题
      Text(this.getTitle())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(gc('text_primary'))
        .margin({ top: 8, bottom: 16 })
      
      // 选项列表
      Column() {
        ForEach(this.getOptions(), (option: SelectOption, index: number) => {
          this.OptionItem(option, index, this.getOptions().length)
        }, (option: SelectOption) => option.value)
      }
      .width('100%')
      .backgroundColor(gc('bg_primary'))
      .borderRadius(12)
      .clip(true)
      
      // 取消按钮
      Button(t('cancel', this.languageVersion))
        .width('100%')
        .height(44)
        .fontSize(16)
        .fontColor(gc('text_secondary'))
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: gc('divider') })
        .borderRadius(12)
        .margin({ top: 16 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('85%')
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(16)
    .padding(20)
    .shadow({ radius: 8, color: '#15000000', offsetY: 4 })
  }
  
  // 选项项组件
  @Builder
  OptionItem(option: SelectOption, index: number, totalCount: number) {
    Column() {
      Row() {
        // 如果是主题色选择，显示对应的颜色圆点
        if (this.isColorTheme(option.value)) {
          Circle()
            .width(18)
            .height(18)
            .fill(this.getColorHex(option.value))
            .margin({ right: 12 })
            .shadow({ radius: 2, color: '#20000000', offsetY: 1 })
        }

        Text(option.label)
          .fontSize(16)
          .fontWeight(this.currentValue === option.value ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentValue === option.value ? gc('accent') : gc('text_primary'))
          .layoutWeight(1)
        
        if (this.currentValue === option.value) {
          // 选中图标
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([gc('accent')])
            .fontWeight(FontWeight.Bold)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onSelected(option.value);
        this.controller.close();
      })

      if (index < totalCount - 1) {
        Divider()
          .color(gc('divider'))
          .strokeWidth(0.5)
          .margin({ left: 16, right: 16 })
      }
    }
  }
}

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
  // 弹窗控制器
  controller: CustomDialogController;
  
  // 弹窗参数
  @Prop title: string = '请选择';
  @Prop options: SelectOption[] = [];
  @Prop currentValue: string = '';
  
  // 选择回调
  onSelected: (value: string) => void = (_value: string) => {};
  
  build() {
    Column() {
      // 标题
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary'))
        .margin({ top: 20, bottom: 16 })
      
      // 选项列表
      Column() {
        ForEach(this.options, (option: SelectOption, index: number) => {
          this.OptionItem(option, index)
        }, (option: SelectOption) => option.value)
      }
      .width('100%')
      
      // 取消按钮
      Button(t('cancel'))
        .width('100%')
        .height(44)
        .fontSize(16)
        .fontColor(gc('accent'))
        .backgroundColor(gc('bg_primary'))
        .margin({ top: 16 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('85%')
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(16)
    .padding(20)
  }
  
  // 选项项组件
  @Builder
  OptionItem(option: SelectOption, index: number) {
    Row() {
      Text(option.label)
        .fontSize(16)
        .fontColor(this.currentValue === option.value ? gc('accent') : gc('text_primary'))
        .layoutWeight(1)
      
      if (this.currentValue === option.value) {
        // 选中图标
        Text('✓')
          .fontSize(18)
          .fontColor(gc('accent'))
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(index % 2 === 0 ? gc('bg_primary') : gc('bg_secondary'))
    .borderRadius(8)
    .onClick(() => {
      this.onSelected(option.value);
      this.controller.close();
    })
  }
}

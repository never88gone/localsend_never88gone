import { gc } from '../utils/ThemeManager';
import router from '@ohos.router';

@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop centerTitle: boolean = true;
  @Prop showBackButton: boolean = true;
  @Prop showActionButton: boolean = false;
  @Prop actionIcon: Resource = $r('sys.symbol.trash');
  @Prop themeVersion: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  onActionClick: () => void = () => {};

  build() {
    Row() {
      // 1. 左侧占位/返回按钮区域
      Row() {
        if (this.showBackButton) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(24)
              .fontColor([gc('text_primary', this.themeVersion)])
          }
          .width(44)
          .height(44)
          .backgroundColor(gc('transparent', this.themeVersion))
          .onClick(() => {
            router.back();
          })
        }
      }
      .width(56)
      .justifyContent(FlexAlign.Start)

      // 2. 中间标题区域
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary', this.themeVersion))
        .textAlign(this.centerTitle ? TextAlign.Center : TextAlign.Start)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 3. 右侧占位/操作按钮区域
      Row() {
        if (this.showActionButton) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.actionIcon)
              .fontSize(22)
              .fontColor([gc('text_secondary', this.themeVersion)])
          }
          .width(44)
          .height(44)
          .backgroundColor(gc('transparent', this.themeVersion))
          .onClick(() => {
            this.onActionClick();
          })
        }
      }
      .width(56)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(56 + px2vp(this.statusBarHeight))
    .padding({
      top: px2vp(this.statusBarHeight) + 8,
      bottom: 8,
      left: 16,
      right: 16
    })
  }
}

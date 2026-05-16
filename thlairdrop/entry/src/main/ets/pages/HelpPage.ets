import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import router from '@ohos.router';

@Entry
@Component
struct HelpPage {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  build() {
    Scroll() {
      Column() {
        // 顶部导航栏
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(24)
              .fontColor([gc('text_primary')])
          }
          .width(44)
          .height(44)
          .backgroundColor(gc('transparent'))
          .onClick(() => {
            router.back();
          })

          Text(t('help', this.languageVersion))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(gc('text_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 占位，保持标题居中
          Row()
            .width(44)
            .height(44)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 20, bottom: 16 })

        // 帮助内容
        Column() {
          // 应用介绍
          this.HelpSection(
            t('app_intro_title', this.languageVersion),
            t('app_intro_content', this.languageVersion)
          )

          // 如何发送文件
          this.HelpSection(
            t('how_to_send_title', this.languageVersion),
            t('how_to_send_content', this.languageVersion)
          )

          // 如何接收文件
          this.HelpSection(
            t('how_to_receive_title', this.languageVersion),
            t('how_to_receive_content', this.languageVersion)
          )

          // 注意事项
          this.HelpSection(
            t('notes_title', this.languageVersion),
            t('notes_content', this.languageVersion)
          )
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 40 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(gc('bg_primary'))
    .key(`help_scroll_${this.refreshKey}`)
  }

  @Builder HelpSection(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      Text(content)
        .fontSize(15)
        .fontColor(gc('text_secondary'))
        .width('100%')
        .lineHeight(24)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(gc('bg_secondary'))
    .borderRadius(12)
    .margin({ bottom: 16 })
  }
}

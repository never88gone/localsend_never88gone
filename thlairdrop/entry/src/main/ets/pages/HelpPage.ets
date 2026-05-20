import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import router from '@ohos.router';
import { PageHeader } from '../components/PageHeader';

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
    Stack() {
      // 1. 背景色容器 (铺满屏幕)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 实际内容容器 (安全区内)
      Column() {
        PageHeader({
          title: t('help', this.languageVersion),
          centerTitle: true,
          themeVersion: this.themeVersion
        })

        // 可滚动的内容区
        Scroll() {
          Column() {
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
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .key(`help_scroll_${this.refreshKey}`)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder HelpSection(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(gc('text_primary', this.themeVersion))
        .width('100%')
        .margin({ bottom: 12 })

      Text(content)
        .fontSize(15)
        .fontColor(gc('text_secondary', this.themeVersion))
        .width('100%')
        .lineHeight(24)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(gc('bg_secondary', this.themeVersion))
    .borderRadius(12)
    .margin({ bottom: 16 })
  }
}

import { gc, ThemeManager } from '../utils/ThemeManager';
import router from '@ohos.router';
import { PageHeader } from '../components/PageHeader';
import { t } from '../utils/I18nManager';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';

@Entry
@Component
struct PrivacyPolicy {
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
          title: t('privacy_policy_title', this.languageVersion),
          centerTitle: true,
          themeVersion: this.themeVersion
        })

        // 可滚动的内容区
        Scroll() {
          Column() {
            // 内容区
            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.info_circle'))
                  .fontSize(16)
                  .fontColor([gc('accent', this.themeVersion)])
                  .margin({ right: 8 })
                Text('查看在线最新隐私政策')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(gc('accent', this.themeVersion))
              }
              .width('100%')
              .padding(14)
              .margin({ bottom: 12 })
              .backgroundColor(gc('bg_secondary', this.themeVersion))
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                const context = getContext(this) as common.UIAbilityContext;
                context?.openLink('https://www.myit2017.cn/privacy/thl-send').catch((err: Error) => {
                  hilog.error(0x0000, 'PrivacyPolicy', 'Failed to open link: ' + err.message);
                });
              })

              Column() {
                Text(t('privacy_policy_content', this.languageVersion))
                  .fontSize(15)
                  .fontColor(gc('text_secondary', this.themeVersion))
                  .width('100%')
                  .lineHeight(24)
              }
              .width('100%')
              .padding(20)
              .backgroundColor(gc('bg_secondary', this.themeVersion))
              .borderRadius(12)
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
        .key(`privacy_scroll_${this.refreshKey}`)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}

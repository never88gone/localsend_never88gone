import router from '@ohos.router';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import { PageHeader } from '../components/PageHeader';

@Entry
@Component
struct ThirdPartyLicenses {
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  
  get bottomPadding(): number {
    const navBarVp = px2vp(this.navigationBarHeight);
    return navBarVp > 0 ? Math.max(navBarVp, 28) : 28;
  }
  
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
          title: t('third_party', this.languageVersion),
          centerTitle: true,
          themeVersion: this.themeVersion
        })
        
        Divider()
          .color(gc('divider', this.themeVersion))
        
        // 第三方组件列表 (可滚动)
        Scroll() {
          Column() {
            // LocalSend
            Column() {
              Row() {
                Text('LocalSend')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(gc('text_primary', this.themeVersion))
                
                Blank()
                
                Text('MIT License')
                  .fontSize(14)
                  .fontColor(gc('text_secondary', this.themeVersion))
              }
              .width('100%')
              .padding({ top: 16, bottom: 8 })
              
              Text(t('third_party_localsend_desc', this.languageVersion))
                .fontSize(14)
                .fontColor(gc('text_secondary', this.themeVersion))
                .width('100%')
                .margin({ bottom: 8 })
              
              Row() {
                Text('GitHub: ')
                  .fontSize(14)
                  .fontColor(gc('text_secondary', this.themeVersion))
                
                Text('https://github.com/localsend/localsend')
                  .fontSize(14)
                  .fontColor(gc('accent', this.themeVersion))
              }
              .width('100%')
              .margin({ bottom: 16 })
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(12)
            .margin({ bottom: 16 })
            
            // 说明文字
            Column() {
              Text(t('third_party_ack_title', this.languageVersion))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary', this.themeVersion))
                .width('100%')
                .margin({ bottom: 12 })
              
              Text(t('third_party_ack_content', this.languageVersion))
                .fontSize(14)
                .fontColor(gc('text_secondary', this.themeVersion))
                .width('100%')
                .lineHeight(22)
            }
            .width('100%')
            .padding(20)
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(12)
            .margin({ bottom: 32 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 40 })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.bottomPadding })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .key(`licenses_column_${this.refreshKey}`)
  }
}

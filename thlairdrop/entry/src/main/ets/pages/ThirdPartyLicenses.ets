import router from '@ohos.router';
import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

@Entry
@Component
struct ThirdPartyLicenses {
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([gc('text_primary')])
        }
        .width(48)
        .height(48)
        .backgroundColor(gc('transparent'))
        .onClick(() => {
          router.back();
        })
        
        Text(t('third_party', this.languageVersion))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(gc('text_primary'))
          .margin({ left: 8 })
        
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      
      Divider()
        .color(gc('divider'))
      
      // 第三方组件列表
      Scroll() {
        Column() {
          // LocalSend
          Column() {
            Row() {
              Text('LocalSend')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(gc('text_primary'))
              
              Blank()
              
              Text('MIT License')
                .fontSize(14)
                .fontColor(gc('text_secondary'))
            }
            .width('100%')
            .padding({ top: 16, bottom: 8 })
            
            Text('跨平台文件传输应用，基于 LocalSend 协议实现局域网设备发现和文件传输功能。')
              .fontSize(14)
              .fontColor(gc('text_secondary'))
              .width('100%')
              .margin({ bottom: 8 })
            
            Row() {
              Text('GitHub: ')
                .fontSize(14)
                .fontColor(gc('text_secondary'))
              
              Text('https://github.com/localsend/localsend')
                .fontSize(14)
                .fontColor(gc('accent'))
            }
            .width('100%')
            .margin({ bottom: 16 })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .backgroundColor(gc('bg_secondary'))
          .borderRadius(12)
          .margin({ top: 16, left: 16, right: 16, bottom: 16 })
          
          // 说明文字
          Column() {
            Text('致谢')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(gc('text_primary'))
              .width('100%')
              .margin({ bottom: 12 })
            
            Text('本项目基于 LocalSend 开源项目开发，感谢 LocalSend 团队的开源贡献。LocalSend 提供了跨设备文件传输的核心协议和实现思路。')
              .fontSize(14)
              .fontColor(gc('text_secondary'))
              .width('100%')
              .lineHeight(22)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(gc('bg_secondary'))
          .borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 32 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary'))
    .key(`licenses_column_${this.refreshKey}`)
  }
}

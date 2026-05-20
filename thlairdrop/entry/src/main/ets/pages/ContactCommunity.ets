import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import { PageHeader } from '../components/PageHeader';

@Entry
@Component
struct ContactCommunity {
  @StorageProp('appTheme') currentTheme: string = 'system';
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  // 打开链接
  private openUrl(url: string) {
    const context = getContext(this) as common.UIAbilityContext;
    context?.openLink(url).catch((err: Error) => {
      hilog.error(0x0000, 'ContactCommunity', 'Failed to open link ' + url + ': ' + err.message);
      promptAction.showToast({ message: '无法打开网页' });
    });
  }

  // 复制文本到剪贴板
  private copyToClipboard(text: string, toastMessage: string) {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
      promptAction.showToast({ message: toastMessage });
    } catch (err) {
      hilog.error(0x0000, 'ContactCommunity', 'Failed to copy text: ' + err.message);
    }
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
          title: t('contact_community', this.languageVersion),
          centerTitle: true,
          themeVersion: this.themeVersion
        })

        // 可滚动的内容区
        Scroll() {
          Column() {
            // 联系信息卡片
            Column() {
              ContactRow({
                label: t('contact_github', this.languageVersion),
                value: 'localsend_never88gone',
                themeVersion: this.themeVersion,
                onItemClick: (): void => { this.openUrl('https://github.com/never88gone/localsend_never88gone'); }
              })
              
              Divider().color(gc('divider', this.themeVersion)).strokeWidth(1)
              
              ContactRow({
                label: t('contact_telegram', this.languageVersion),
                value: '@tanghulutvos',
                themeVersion: this.themeVersion,
                onItemClick: (): void => { this.openUrl('https://t.me/tanghulutvos'); }
              })
              
              Divider().color(gc('divider', this.themeVersion)).strokeWidth(1)
              
              ContactRow({
                label: t('contact_email', this.languageVersion),
                value: 'hsb@myit2017.cn',
                themeVersion: this.themeVersion,
                onItemClick: (): void => {
                  this.copyToClipboard('hsb@myit2017.cn', t('copied_toast', this.languageVersion));
                }
              })
              
              Divider().color(gc('divider', this.themeVersion)).strokeWidth(1)
              
              ContactRow({
                label: t('contact_website', this.languageVersion),
                value: 'myit2017.cn',
                themeVersion: this.themeVersion,
                onItemClick: (): void => { this.openUrl('https://www.myit2017.cn'); }
              })
            }
            .width('100%')
            .backgroundColor(gc('bg_secondary', this.themeVersion))
            .borderRadius(16)
            .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
            .clip(true)
            .margin({ top: 8, bottom: 40 })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .key(`contact_scroll_${this.refreshKey}`)
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

@Component
struct ContactRow {
  @Prop label: string;
  @Prop value: string;
  @Prop themeVersion: number;
  onItemClick: () => void = (): void => {};
  @State isPressed: boolean = false;

  build() {
    Row() {
      Text(this.label)
        .fontSize(16)
        .fontColor(gc('text_primary', this.themeVersion))
        .layoutWeight(1)

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
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(this.isPressed ? gc('accent_bg', this.themeVersion) : Color.Transparent)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick((): void => {
      this.onItemClick();
    })
  }
}

import { gc, ThemeManager } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';
import { SendTab } from '../components/SendTab';
import { ReceiveTab } from '../components/ReceiveTab';
import { SettingsTab } from '../components/SettingsTab';
import { localSendService, Device, NetworkInfo } from '../service/LocalSendService';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State devices: Device[] = [];
  @State isScanning: boolean = false;
  
  // 共享状态
  @StorageLink('appAliasName') aliasName: string = 'HarmonyOS Device';
  @StorageLink('appQuickSaveMode') quickSaveMode: number = 0;
  @StorageLink('appAnimationEnabled') animationEnabled: boolean = true;
  @StorageLink('appPort') port: number = 53317;
  @StorageLink('appSaveDir') saveDir: string = '下载';
  @StorageLink('appIsServerRunning') isServerRunning: boolean = true;
  @StorageLink('appLocalIps') localIps: string[] = [];
  
  // 动画角度
  @State animationAngle: number = 0;
  
  // 响应式触发器
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }
  
  // 显示高级信息
  @State showAdvancedInfo: boolean = false;

  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear() {
    // 注册设备发现回调 (解析 JSON 字符串)
    localSendService.setDeviceCallback((deviceJson: string) => {
      try {
        const devices = JSON.parse(deviceJson) as Device[];
        this.devices = devices;
      } catch (e) {
        console.error('Failed to parse device JSON:', e);
      }
    });

    // 启动动画定时器
    setInterval(() => {
      if (this.isServerRunning) {
        this.animationAngle = (this.animationAngle + 2) % 360;
      }
    }, 30);

    // 获取并定时更新本地网络信息
    this.updateNetworkInfo();
    setInterval(() => {
      this.updateNetworkInfo();
    }, 5000);

    // 初始扫描
    localSendService.scanDevices();
  }

  private updateNetworkInfo() {
    const info = localSendService.getNetworkInfo();
    if (info && info.ip) {
      // 本地 IP 可能有多个，这里简单处理，实际可根据 native 返回解析
      if (!this.localIps.includes(info.ip)) {
        this.localIps = [info.ip];
      }
    }
  }

  @Builder TabBuilder(title: string, targetIndex: number, selectedIcon: Resource, normalIcon: Resource) {
    Column() {
      SymbolGlyph(this.currentIndex === targetIndex ? selectedIcon : normalIcon)
        .fontSize(24)
        .fontColor([this.currentIndex === targetIndex ? gc('accent', this.themeVersion) : gc('text_tertiary', this.themeVersion)])
        .margin({ bottom: 4 })
      
      Text(t(title, this.languageVersion))
        .key(`tab_text_${this.refreshKey}`)
        .fontColor(this.currentIndex === targetIndex ? gc('accent', this.themeVersion) : gc('text_tertiary', this.themeVersion))
        .fontSize(12)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
    })
  }

  build() {
    Column() {
      // 内容区域
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          ReceiveTab({
            isServerRunning: $isServerRunning,
            localIps: $localIps,
            quickSaveMode: $quickSaveMode,
            showAdvancedInfo: $showAdvancedInfo,
            animationAngle: $animationAngle,
            aliasName: $aliasName,
            saveDir: $saveDir,
            port: $port
          })
        }.tabBar(this.TabBuilder('tab_receive', 0, $r('sys.symbol.arrow_down_circle'), $r('sys.symbol.arrow_down_circle')))

        TabContent() {
          SendTab({
            devices: $devices,
            isScanning: this.isScanning
          })
        }.tabBar(this.TabBuilder('tab_send', 1, $r('sys.symbol.paperplane'), $r('sys.symbol.paperplane')))

        TabContent() {
          SettingsTab({
            aliasName: $aliasName,
            quickSaveMode: $quickSaveMode,
            animationEnabled: $animationEnabled,
            port: $port,
            saveDir: $saveDir
          })
        }.tabBar(this.TabBuilder('tab_settings', 2, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape')))
      }
      .scrollable(false)
      .barHeight(60)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary', this.themeVersion))
  }
}

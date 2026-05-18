import { gc, ThemeManager } from '../utils/ThemeManager';
import { I18nManager, t } from '../utils/I18nManager';
import { SendTab } from '../components/SendTab';
import { ReceiveTab } from '../components/ReceiveTab';
import { SettingsTab } from '../components/SettingsTab';
import { localSendService, Device } from '../service/LocalSendService';
import { SettingsService, AppSettings } from '../services/SettingsService';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';

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
  @Watch('onServerToggle') @StorageLink('appIsServerRunning') isServerRunning: boolean = true;
  @StorageLink('appLocalIps') localIps: string[] = [];
  @StorageLink('appTheme') theme: string = 'system';
  @StorageLink('appColorTheme') colorTheme: string = 'blue';
  @StorageLink('appLanguage') language: string = 'system';
  
  // 动画角度
  @State animationAngle: number = 0;
  
  // 响应式触发器
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  onServerToggle() {
    this.manageServer();
  }
  
  // 显示高级信息
  @State showAdvancedInfo: boolean = false;

  private context = getContext(this) as common.UIAbilityContext;
  private settingsService: SettingsService = SettingsService.getInstance();
  private scanInterval: number = 0;
  private announceInterval: number = 0;

  async aboutToAppear() {
    // 1. 确保设置已加载（EntryAbility已预加载，这里确保Service初始化）
    await this.ensureSettingsLoaded();

    // 2. 注册设备发现回调
    localSendService.setDeviceCallback((deviceJson: string) => {
      try {
        const devices = JSON.parse(deviceJson) as Device[];
        this.devices = devices;
      } catch (e) {
        hilog.error(0x0000, 'Index', 'Failed to parse device JSON: ' + (e as Error).message);
      }
    });

    // 3. 启动动画定时器
    setInterval(() => {
      if (this.isServerRunning) {
        this.animationAngle = (this.animationAngle + 2) % 360;
      }
    }, 30);

    // 4. 自动管理服务器生命周期
    this.manageServer();

    // 5. 启动自动发现定时器
    this.startAutoDiscovery();
  }

  /**
   * 确保设置已加载
   * EntryAbility已提前加载设置到AppStorage，这里只需确保Service初始化
   */
  private async ensureSettingsLoaded(): Promise<void> {
    // 确保SettingsService已初始化
    if (!this.settingsService.getContext()) {
      await this.settingsService.init(this.context);
    }
    
    // 触发一次UI刷新以确保响应式更新
    ThemeManager.incrementThemeVersion();
    I18nManager.incrementLanguageVersion();
    
    hilog.info(0x0000, 'Index', 'Settings ensured, theme=%{public}s, colorTheme=%{public}s', 
      this.theme, this.colorTheme);
  }

  aboutToDisappear() {
    this.stopAutoDiscovery();
    localSendService.stop();
  }

  /**
   * 根据状态管理服务器启动/停止
   */
  private manageServer() {
    if (this.isServerRunning) {
      const success = localSendService.start(this.aliasName, this.port);
      if (success) {
        this.updateNetworkInfo();
      }
    } else {
      localSendService.stop();
    }
  }

  /**
   * 更新本地网络信息
   */
  private updateNetworkInfo() {
    const info = localSendService.getNetworkInfo();
    if (info && info.ip) {
      this.localIps = [info.ip];
    }
  }

  /**
   * 启动自动发现
   */
  private startAutoDiscovery() {
    this.stopAutoDiscovery();
    
    // 立即执行一次
    localSendService.scanDevices();
    
    // 定时扫描 (10秒一次)
    this.scanInterval = setInterval(() => {
      if (this.currentIndex === 1) { // 仅在发送页活跃时扫描
        localSendService.scanDevices();
      }
    }, 10000);

    // 定时发送公告 (15秒一次)，让别人发现我
    this.announceInterval = setInterval(() => {
      if (this.isServerRunning) {
        localSendService.sendAnnouncement();
      }
    }, 15000);
  }

  /**
   * 停止自动发现
   */
  private stopAutoDiscovery() {
    if (this.scanInterval) {
      clearInterval(this.scanInterval);
    }
    if (this.announceInterval) {
      clearInterval(this.announceInterval);
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
      // 切换到发送页时立即扫描一次
      if (targetIndex === 1) {
        localSendService.scanDevices();
      }
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
    // 监听服务器开关变化
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible) {
        this.manageServer();
      }
    })
  }
}

import { gc, ThemeManager } from '../utils/ThemeManager';
import { I18nManager, t } from '../utils/I18nManager';
import { SendTab } from '../components/SendTab';
import { ReceiveTab } from '../components/ReceiveTab';
import { SettingsTab } from '../components/SettingsTab';
import { localSendService, Device, DeviceType } from '../service/LocalSendService';
import { SettingsService, AppSettings } from '../services/SettingsService';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

interface RawDevice {
  ip?: string;
  address?: string;
  alias?: string;
  version?: string;
  port?: number;
  https?: boolean;
  fingerprint?: string;
  deviceModel?: string;
  deviceType?: string;
  device_type?: string;
  download?: boolean;
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State devices: Device[] = [];
  @State isScanning: boolean = false;
  
  // 共享状态
  @StorageLink('appAliasName') aliasName: string = '糖葫芦投送';
  @StorageLink('appQuickSaveMode') quickSaveMode: number = 0;
  @StorageLink('appAnimationEnabled') animationEnabled: boolean = true;
  @StorageLink('appPort') port: number = 53317;
  @StorageLink('appSaveDir') saveDir: string = '下载';
  @Watch('onServerToggle') @StorageLink('appIsServerRunning') isServerRunning: boolean = true;
  @StorageLink('appLocalIps') localIps: string[] = [];
  @StorageLink('appTheme') theme: string = 'system';
  @StorageLink('appColorTheme') colorTheme: string = 'blue';
  @StorageLink('appLanguage') language: string = 'system';
  @StorageLink('appPrivacyAccepted') privacyAccepted: boolean = false;
  
  // 动画角度
  @State animationAngle: number = 0;
  
  // 响应式触发器
  @Watch('onRefreshTriggered') @StorageProp('themeVersion') themeVersion: number = 0;
  @Watch('onRefreshTriggered') @StorageProp('languageVersion') languageVersion: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @State refreshKey: number = 0;
  
  onRefreshTriggered() {
    this.refreshKey++;
  }

  onServerToggle() {
    if (this.privacyAccepted) {
      this.manageServer();
    }
  }
  
  // 显示高级信息
  @State showAdvancedInfo: boolean = false;

  private context = getContext(this) as common.UIAbilityContext;
  private settingsService: SettingsService = SettingsService.getInstance();
  private scanInterval: number = 0;
  private announceInterval: number = 0;
  private deviceCallback = (deviceJson: string) => {
    try {
      const rawDevices = JSON.parse(deviceJson) as RawDevice[];
      this.devices = rawDevices.map((d: RawDevice): Device => ({
        ip: d.ip || d.address || '',
        alias: d.alias || '',
        version: d.version || '',
        port: d.port || 53317,
        https: d.https || false,
        fingerprint: d.fingerprint || '',
        deviceModel: d.deviceModel || 'Unknown',
        deviceType: (d.deviceType || d.device_type || 'mobile') as DeviceType,
        download: d.download || false
      }));
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to parse device JSON: ' + (e as Error).message);
    }
  };

  // 声明隐私政策弹窗控制器
  private privacyDialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyDialog({
      themeVersion: this.themeVersion,
      onAccept: () => {
        this.acceptPrivacy();
      },
      onDecline: () => {
        this.declinePrivacy();
      }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  async aboutToAppear() {
    // 1. 确保设置已加载（EntryAbility已预加载，这里确保Service初始化）
    await this.ensureSettingsLoaded();

    // 2. 检查是否同意了隐私协议
    if (this.privacyAccepted) {
      this.initAppServices();
    } else {
      // 延迟展示弹窗，确保页面已经加载好
      setTimeout(() => {
        if (this.privacyDialogController) {
          this.privacyDialogController.open();
        }
      }, 500);
    }
  }



  // 接受隐私协议
  private async acceptPrivacy(): Promise<void> {
    this.privacyAccepted = true;
    await this.settingsService.setPrivacyAccepted(true);
    
    // 同意后启动相关后台服务与扫描
    this.initAppServices();
  }

  // 不同意隐私协议，退出应用
  private declinePrivacy(): void {
    try {
      this.context.terminateSelf();
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to terminate self: ' + (e as Error).message);
    }
  }

  // 初始化相关核心服务
  private initAppServices() {
    // 1. 注册设备发现回调
    localSendService.registerDeviceCallback(this.deviceCallback);

    // 2. 启动动画定时器
    setInterval(() => {
      if (this.isServerRunning) {
        this.animationAngle = (this.animationAngle + 2) % 360;
      }
    }, 30);

    // 3. 自动管理服务器生命周期
    this.manageServer();

    // 4. 启动自动发现定时器
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
    localSendService.unregisterDeviceCallback(this.deviceCallback);
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
      // M3 Active Indicator 选中指示背景
      Stack() {
        SymbolGlyph(this.currentIndex === targetIndex ? selectedIcon : normalIcon)
          .fontSize(22)
          .fontColor([this.currentIndex === targetIndex ? gc('accent', this.themeVersion) : gc('text_tertiary', this.themeVersion)])
      }
      .width(60)
      .height(32)
      .borderRadius(16)
      .backgroundColor(this.currentIndex === targetIndex ? gc('accent_bg', this.themeVersion) : Color.Transparent)
      .alignContent(Alignment.Center)
      .margin({ top: 12, bottom: 4 })
      
      Text(t(title, this.languageVersion))
        .key(`tab_text_${this.refreshKey}`)
        .fontColor(this.currentIndex === targetIndex ? gc('accent', this.themeVersion) : gc('text_tertiary', this.themeVersion))
        .fontSize(12)
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .margin({ bottom: 10 })
    }
    .width('100%')
    .height(80)
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
    Stack() {
      // 1. 背景色容器 (铺满屏幕)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(gc('bg_primary', this.themeVersion))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 实际内容容器 (安全区内)
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
          }.tabBar(this.TabBuilder('tab_send', 1, $r('sys.symbol.paperplane_fill'), $r('sys.symbol.paperplane')))

          TabContent() {
            SettingsTab({
              aliasName: $aliasName,
              quickSaveMode: $quickSaveMode,
              animationEnabled: $animationEnabled,
              port: $port,
              saveDir: $saveDir
            })
          }.tabBar(this.TabBuilder('tab_settings', 2, $r('sys.symbol.gearshape_fill'), $r('sys.symbol.gearshape')))
        }
        .scrollable(false)
        .barHeight(80)
        .barMode(BarMode.Fixed)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      }
      .width('100%')
      .height('100%')
      .padding({ top: px2vp(this.statusBarHeight) })
      // 监听服务器开关变化
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
        if (isVisible && this.privacyAccepted) {
          this.manageServer();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 首次启动隐私政策与服务协议授权弹窗
 */
@CustomDialog
struct PrivacyDialog {
  controller: CustomDialogController;
  onAccept: () => void = () => {};
  onDecline: () => void = () => {};
  @Prop themeVersion: number;

  build() {
    Column() {
      // 头部装饰
      Row() {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(24)
          .fontColor([gc('accent', this.themeVersion)])
          .margin({ right: 8 })
        Text('关于隐私与安全的说明')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(gc('text_primary', this.themeVersion))
      }
      .margin({ top: 12, bottom: 16 })
      
      Scroll() {
        Column() {
          Text('欢迎使用糖葫芦快传！\n\n' +
               '本应用是一款【纯单机免服务器】的局域网点对点（P2P）文件与文本传输工具。为了保障您的知情权，在此向您说明：\n\n' +
               '1. 纯单机运行，无云端收集：本应用不设任何云端服务器，您的所有文件、文本内容和传输记录，均仅在您本地的局域网内设备之间进行直连点对点传递。我们不会、也无法收集或上传您的任何个人隐私数据。\n\n' +
               '2. 核心权限使用说明：\n' +
               '• 局域网设备扫描与连接：为寻找并直连同一网络下的其他设备，应用会申请WLAN与网络连接状态权限。\n' +
               '• 文件读取与写入：为允许您选择发送的文件，以及将接收到的文件保存到本地，应用会申请读取和写入媒体文件的权限。所有文件操作均在您的本地设备上执行。\n\n' +
               '3. 纯净无广告：本应用不包含任何广告插件与第三方追踪组件，请您放心使用。\n\n' +
               '点击“我知道了并继续”代表您已了解并同意上述说明，本应用将正常为您开启局域网通信与文件读写传输服务。若不同意，应用将无法完成局域网点对点快传。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(gc('text_secondary', this.themeVersion))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .height(240)
      .margin({ bottom: 20 })

      Row() {
        Button('不同意并退出')
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(gc('text_secondary', this.themeVersion))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: gc('divider', this.themeVersion) })
          .borderRadius(12)
          .height(40)
          .onClick(() => {
            this.controller.close();
            this.onDecline();
          })

        Blank().width(16)

        Button('我知道了并继续')
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(gc('accent', this.themeVersion))
          .borderRadius(12)
          .height(40)
          .onClick(() => {
            this.controller.close();
            this.onAccept();
          })
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
    .width('90%')
    .padding(20)
    .backgroundColor(gc('bg_secondary', this.themeVersion))
    .borderRadius(16)
  }
}

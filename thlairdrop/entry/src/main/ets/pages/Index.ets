import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import wifiManager from '@ohos.wifiManager';

import { ReceiveTab } from '../components/ReceiveTab';
import { SendTab } from '../components/SendTab';
import { SettingsTab } from '../components/SettingsTab';
import libEntry from 'libentry.so';
import { localSendService, Device } from '../service/LocalSendService';
import { SettingsService } from '../services/SettingsService';
import { gc } from '../utils/ThemeManager';
import { t } from '../utils/I18nManager';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State discoveredDevices: Device[] = [];
  
  // 核心状态
  @Watch('onAliasChanged') @State aliasName: string = 'HarmonyOS 设备';
  @Watch('onServerStatusChanged') @State isServerRunning: boolean = true;
  @State localIps: string[] = ['127.0.0.1'];
  @State quickSaveMode: number = 0;
  @State showAdvancedInfo: boolean = false;
  @State animationAngle: number = 0;
  @State animationEnabled: boolean = true;
  @State port: number = 53317;
  @State saveDir: string = '下载';
  
  @StorageLink('appLanguage') appLanguage: string = 'zh';
  @StorageLink('appTheme') appTheme: string = 'light';
  @StorageLink('appColorTheme') appColorTheme: string = 'blue';
  
  // 设置服务
  private settingsService: SettingsService = SettingsService.getInstance();
  private isSettingsLoaded: boolean = false;
  
  onServerStatusChanged() {
    if (!this.isSettingsLoaded) return;
    hilog.info(0x0000, 'Index', 'Server status changed to: ' + this.isServerRunning);
    try {
      if (this.isServerRunning) {
        libEntry.startServer(this.aliasName, this.port);
      } else {
        libEntry.stopServer();
      }
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to toggle server status');
    }
  }
  
  onAliasChanged() {
    if (!this.isSettingsLoaded) return;
    hilog.info(0x0000, 'Index', 'Alias changed to: ' + this.aliasName);
    // 保存别名到设置
    this.settingsService.setAliasName(this.aliasName);
    try {
      libEntry.stopServer();
      libEntry.startServer(this.aliasName, this.port);
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to restart server on alias change');
    }
  }
  
  private tabsController: TabsController = new TabsController();
  private timerId: number = -1;
  private scanIntervalId: number = -1;

  aboutToAppear() {
    hilog.info(0x0000, 'Index', 'Starting App');
    
    // 初始化应用
    this.initApp();
    
    this.startAnimation();
    this.updateLocalIps();

    // 定时扫描设备
    this.scanIntervalId = setInterval(() => {
      if (this.currentIndex === 1) {
        this.scanDevices();
      }
    }, 3000);
  }
  
  private async initApp() {
    // 初始化设置服务
    await this.settingsService.init(getContext(this) as common.UIAbilityContext);
    
    // 加载保存的设置
    await this.loadSettings();
  }
  
  // 加载设置
  private async loadSettings(): Promise<void> {
    try {
      const settings = await this.settingsService.getSettings();
      this.aliasName = settings.aliasName;
      this.quickSaveMode = settings.quickSaveMode;
      this.animationEnabled = settings.animationEnabled;
      this.port = settings.port;
      this.saveDir = settings.saveDir;
      
      // 全局应用主题和语言
      AppStorage.setOrCreate('appTheme', settings.theme);
      AppStorage.setOrCreate('appLanguage', settings.language);
      AppStorage.setOrCreate('appColorTheme', settings.colorTheme);
      
      this.isSettingsLoaded = true;
      
      // 设置加载完成后启动服务器
      this.isServerRunning = libEntry.startServer(this.aliasName, this.port);
      hilog.info(0x0000, 'Index', 'Settings loaded, server started: ' + this.isServerRunning);
    } catch (err) {
      const error = err as Error;
      hilog.error(0x0000, 'Index', 'Failed to load settings: ' + error.message);
      this.isSettingsLoaded = true;
      // 使用默认设置启动服务器
      this.isServerRunning = libEntry.startServer(this.aliasName, this.port);
    }
  }

  private scanDevices() {
    try {
      let devices = localSendService.scanDevices();
      if (devices && devices.length > 0) {
        this.discoveredDevices = devices;
      }
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to scan devices: ' + JSON.stringify(e));
    }
  }

  // 更新本地 IP
  updateLocalIps() {
    try {
      let ipInfo = wifiManager.getIpInfo();
      if (ipInfo && ipInfo.ipAddress) {
        let ip = ipInfo.ipAddress;
        let ipString = `${(ip) & 0xFF}.${(ip >> 8) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >>> 24) & 0xFF}`;
        if (!this.localIps.includes(ipString)) {
          this.localIps.push(ipString);
        }
      }
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to get IP from wifiManager: ' + JSON.stringify(e));
    }
  }

  aboutToDisappear() {
    this.stopAnimation();
    if (this.scanIntervalId !== -1) {
      clearInterval(this.scanIntervalId);
    }
    try {
      libEntry.stopServer();
    } catch (e) {
      hilog.error(0x0000, 'Index', 'Failed to stop server');
    }
  }

  startAnimation() {
    if (this.timerId === -1) {
      this.timerId = setInterval(() => {
        if (this.animationEnabled && this.isServerRunning && this.currentIndex === 0) {
          this.animationAngle = (this.animationAngle + 2) % 360;
        }
      }, 50);
    }
  }

  stopAnimation() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  @Builder TabBuilder(title: string, targetIndex: number) {
    Column() {
      // 图标
      if (title === 'tab_receive') {
        // 下载图标
        Column() {
          Path()
            .width(36)
            .height(36)
            .commands('M12 16l-6-6h4V4h4v6h4l-6 6zm-8 4v-2h16v2H4z')
            .fill(this.currentIndex === targetIndex ? gc('accent') : gc('text_tertiary'))
        }
        .width(64)
        .height(36)
        .justifyContent(FlexAlign.Center)
      } else if (title === 'tab_send') {
        // 上传图标
        Column() {
          Path()
            .width(36)
            .height(36)
            .commands('M12 8l6 6h-4v6h-4v-6H6l6-6zm8-4v2H4V4h16z')
            .fill(this.currentIndex === targetIndex ? gc('accent') : gc('text_tertiary'))
        }
        .width(64)
        .height(36)
        .justifyContent(FlexAlign.Center)
      } else {
        // 设置图标
        Column() {
          Path()
            .width(36)
            .height(36)
            .commands('M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.44.17-.47.41l-.37 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.04.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.37-2.54c.59-.24 1.13-.57 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.21.08-.47-.12-.61l-2.03-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z')
            .fill(this.currentIndex === targetIndex ? gc('accent') : gc('text_tertiary'))
        }
        .width(64)
        .height(36)
        .justifyContent(FlexAlign.Center)
      }
      
      Text(t(title))
        .fontColor(this.currentIndex === targetIndex ? gc('accent') : gc('text_tertiary'))
        .fontSize(12)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabsController.changeIndex(this.currentIndex);
    })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        ReceiveTab({ 
          aliasName: $aliasName, 
          isServerRunning: $isServerRunning,
          localIps: $localIps,
          quickSaveMode: $quickSaveMode,
          showAdvancedInfo: $showAdvancedInfo,
          animationAngle: $animationAngle,
          saveDir: $saveDir,
          port: $port
        })
      }
      .tabBar(this.TabBuilder('tab_receive', 0))

      TabContent() {
        SendTab({ devices: $discoveredDevices })
      }
      .tabBar(this.TabBuilder('tab_send', 1))

      TabContent() {
        SettingsTab({
          aliasName: $aliasName,
          quickSaveMode: $quickSaveMode,
          animationEnabled: $animationEnabled,
          port: $port,
          saveDir: $saveDir
        })
      }
      .tabBar(this.TabBuilder('tab_settings', 2))
    }
    .vertical(false)
    .barMode(BarMode.Fixed)
    .barWidth('100%')
    .barHeight(60)
    .animationDuration(300)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor(gc('bg_primary'))
  }
}

import hilog from '@ohos.hilog';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import connection from '@ohos.net.connection';
import deviceInfo from '@ohos.deviceInfo';

import { ReceiveTab } from '../components/ReceiveTab';
import { SendTab } from '../components/SendTab';
import { SettingsTab } from '../components/SettingsTab';
import libEntry from 'libentry.so';
import { DeviceInfo } from '../models/DeviceInfo';
import { SettingsService } from '../services/SettingsService';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State discoveredDevices: DeviceInfo[] = [];
  
  // 核心状态
  @Watch('onAliasChanged') @State aliasName: string = 'HarmonyOS 设备';
  @Watch('onServerStatusChanged') @State isServerRunning: boolean = true;
  @State localIps: string[] = ['127.0.0.1'];

  onServerStatusChanged() {
    hilog.info(0x0000, 'testTag', 'Server status changed to: ' + this.isServerRunning);
    try {
      if (this.isServerRunning) {
        libEntry.startServer(this.aliasName, this.port);
      } else {
        libEntry.stopServer();
      }
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to toggle server status');
    }
  }
  @State quickSaveMode: number = 0; // 0: 关, 1: 收藏, 2: 开
  @State showAdvancedInfo: boolean = false;
  @State animationAngle: number = 0;
  @State animationEnabled: boolean = true;
  @State port: number = 53317;
  
  // 设置服务
  private settingsService: SettingsService = SettingsService.getInstance();
  
  onAliasChanged() {
    hilog.info(0x0000, 'testTag', 'Alias changed to: ' + this.aliasName);
    try {
      libEntry.stopServer();
      libEntry.startServer(this.aliasName, this.port);
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to restart server on alias change');
    }
  }
  
  private tabsController: TabsController = new TabsController();
  private timerId: number = -1;
  private scanIntervalId: number = -1;

  aboutToAppear() {
    hilog.info(0x0000, 'testTag', 'Starting App');
    
    // 初始化设置服务
    this.settingsService.init(getContext(this) as common.UIAbilityContext);
    
    // 加载保存的设置
    this.loadSettings();
    
    this.startAnimation();
    this.updateLocalInfo();

    // 调用 NAPI 启动服务器
    try {
      this.isServerRunning = libEntry.startServer(this.aliasName, this.port);
      hilog.info(0x0000, 'testTag', 'NAPI Server started: ' + this.isServerRunning);
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to start NAPI server: ' + JSON.stringify(e));
    }

    // 定时扫描设备（通过 Rust NAPI）
    this.scanIntervalId = setInterval(() => {
      if (this.currentIndex === 1) { // 仅在发送页扫描
        this.scanDevices();
      }
    }, 3000);
  }
  
  // 加载设置
  private loadSettings(): void {
    this.settingsService.getSettings().then((settings) => {
      this.aliasName = settings.aliasName;
      this.quickSaveMode = settings.quickSaveMode;
      this.animationEnabled = settings.animationEnabled;
      this.port = settings.port;
    }).catch((err: Error) => {
      hilog.error(0x0000, 'testTag', 'Failed to load settings: ' + err.message);
    });
  }

  // 扫描设备（调用 Rust NAPI）
  private scanDevices() {
    try {
      let devicesStr = libEntry.scanDevices();
      hilog.info(0x0000, 'testTag', 'Scanned devices: ' + devicesStr);
      if (devicesStr && devicesStr !== '[]') {
        let devices = JSON.parse(devicesStr) as DeviceInfo[];
        this.discoveredDevices = devices;
      }
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to scan devices: ' + JSON.stringify(e));
    }
  }

  updateLocalInfo() {
    // 获取设备别名
    this.aliasName = deviceInfo.marketName || deviceInfo.productModel || 'HarmonyOS 设备';
    
    // 获取局域网 IP
    connection.getAllNets((err, nets) => {
      if (!err) {
        nets.forEach(net => {
          connection.getConnectionProperties(net, (err, props) => {
            if (!err && props.linkAddresses) {
              props.linkAddresses.forEach(addr => {
                let ip = addr.address.address;
                if (ip && !ip.includes(':') && ip !== '127.0.0.1') {
                  if (!this.localIps.includes(ip)) {
                    this.localIps.push(ip);
                  }
                }
              });
            }
          });
        });
      }
    });

    // 同时尝试从 NAPI 获取更详细的 Rust 侧网络信息
    try {
      let networkInfo = libEntry.getLocalNetworkInfo();
      hilog.info(0x0000, 'testTag', 'NAPI Network Info: ' + networkInfo);
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to get NAPI network info: ' + JSON.stringify(e));
    }
  }

  aboutToDisappear() {
    this.stopAnimation();
    // 清理扫描定时器
    if (this.scanIntervalId !== -1) {
      clearInterval(this.scanIntervalId);
    }
    // 停止服务器
    try {
      libEntry.stopServer();
    } catch (e) {
      hilog.error(0x0000, 'testTag', 'Failed to stop server');
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
      // 使用 Path 代替 Image 占位符
      Path()
        .width(28)
        .height(28)
        .commands(title === '接收' ? 'M12,2 L12,14 M12,14 L16,10 M12,14 L8,10 M4,20 L20,20' : 
                  title === '发送' ? 'M12,22 L12,10 M12,10 L16,14 M12,10 L8,14 M4,4 L20,4' : 
                  'M12,15.5 A3.5,3.5 0 1,1 12,8.5 A3.5,3.5 0 1,1 12,15.5 M19.4,13 L22,13 L22,11 L19.4,11 M4.6,13 L2,13 L2,11 L4.6,11')
        .fill(this.currentIndex === targetIndex ? '#007DFF' : '#999999')
        .stroke(this.currentIndex === targetIndex ? '#007DFF' : '#999999')
        .strokeWidth(2)
      
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? '#007DFF' : '#999999')
        .fontSize(12)
        .margin({ top: 4 })
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
          animationAngle: $animationAngle
        })
      }
      .tabBar(this.TabBuilder('接收', 0))

      TabContent() {
        SendTab({ devices: $discoveredDevices })
      }
      .tabBar(this.TabBuilder('发送', 1))

      TabContent() {
        SettingsTab({
          aliasName: $aliasName,
          quickSaveMode: $quickSaveMode,
          animationEnabled: $animationEnabled,
          port: $port
        })
      }
      .tabBar(this.TabBuilder('设置', 2))
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
    .backgroundColor('#F1F3F5')
  }
}
/**
 * 设备列表组件
 * 
 * 显示已发现的 LocalSend 设备
 */

import { Device, localSendService } from '../service/LocalSendService';

@Component
export struct DeviceList {
  @Link devices: Device[];
  @State isScanning: boolean = false;
  private scanInterval: number = -1;

  aboutToAppear(): void {
    // 自动开始扫描
    this.startScanning();
  }

  aboutToDisappear(): void {
    this.stopScanning();
  }

  /**
   * 开始扫描
   */
  startScanning(): void {
    if (this.isScanning) {
      return;
    }

    this.isScanning = true;
    
    // 立即扫描一次
    this.scan();
    
    // 定期扫描
    this.scanInterval = setInterval(() => {
      this.scan();
    }, 5000); // 每5秒扫描一次
  }

  /**
   * 停止扫描
   */
  stopScanning(): void {
    if (this.scanInterval !== -1) {
      clearInterval(this.scanInterval);
      this.scanInterval = -1;
    }
    this.isScanning = false;
  }

  /**
   * 执行扫描
   */
  private scan(): void {
    const discovered = localSendService.scanDevices(2000);
    
    // 合并新发现的设备
    for (const device of discovered) {
      const existing = this.devices.find(d => d.ip === device.ip);
      if (!existing) {
        this.devices.push(device);
      }
    }
    
    // 同时获取已注册设备
    const registered = localSendService.getRegisteredDevices();
    for (const device of registered) {
      const existing = this.devices.find(d => d.ip === device.ip);
      if (!existing) {
        this.devices.push(device);
      }
    }
  }

  /**
   * 获取设备图标
   */
  private getDeviceIcon(deviceType: string): Resource {
    switch (deviceType) {
      case 'mobile':
        return $r('sys.symbol.smartphone');
      case 'desktop':
        return $r('sys.symbol.desktopcomputer');
      case 'tv':
        return $r('sys.symbol.tv');
      default:
        return $r('sys.symbol.device_phone_portrait');
    }
  }

  /**
   * 格式化设备大小
   */
  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    } else {
      return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('发现的设备')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        
        Blank()
        
        if (this.isScanning) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#007DFF')
        }
        
        Button(this.isScanning ? '停止' : '扫描')
          .fontSize(14)
          .height(32)
          .onClick(() => {
            if (this.isScanning) {
              this.stopScanning();
            } else {
              this.startScanning();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      
      Divider().color('#E5E5E5')
      
      // 设备列表
      if (this.devices.length === 0) {
        Column() {
          Text('暂无设备')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 40 })
          
          Text('请确保其他设备已开启 LocalSend')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.devices, (device: Device, index: number) => {
            ListItem() {
              this.DeviceItem(device)
            }
          }, (device: Device) => device.ip)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: '#F0F0F0' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  DeviceItem(device: Device) {
    Row() {
      // 设备图标
      SymbolGlyph(this.getDeviceIcon(device.deviceType))
        .fontSize(32)
        .fontColor([ '#007DFF' ])
        .margin({ right: 12 })
      
      // 设备信息
      Column() {
        Text(device.alias)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(`${device.ip}:${device.port}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
        
        Text(device.deviceModel)
          .fontSize(11)
          .fontColor('#CCCCCC')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      // 发送按钮
      Button('发送')
        .fontSize(14)
        .height(32)
        .type(ButtonType.Normal)
        .borderRadius(16)
        .onClick(() => {
          // TODO: 打开文件选择器
          console.info(`Send to ${device.alias} (${device.ip})`);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

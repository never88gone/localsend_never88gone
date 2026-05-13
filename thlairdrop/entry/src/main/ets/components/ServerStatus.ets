/**
 * 服务器状态组件
 * 
 * 显示 LocalSend 服务器状态和控制
 */

import { localSendService, NetworkInfo } from '../service/LocalSendService';

@Component
export struct ServerStatus {
  @State isRunning: boolean = false;
  @State networkInfo: NetworkInfo | null = null;
  @Prop alias: string = 'HarmonyOS Device';
  @Prop port: number = 53317;
  
  // 回调
  onStatusChange?: (running: boolean) => void;

  aboutToAppear(): void {
    this.refreshStatus();
  }

  /**
   * 刷新状态
   */
  refreshStatus(): void {
    this.isRunning = localSendService.isRunning();
    this.networkInfo = localSendService.getNetworkInfo();
  }

  /**
   * 启动服务器
   */
  private startServer(): void {
    const success = localSendService.start(this.alias, this.port);
    if (success) {
      this.isRunning = true;
      this.networkInfo = localSendService.getNetworkInfo();
      this.onStatusChange?.(true);
    }
  }

  /**
   * 停止服务器
   */
  private stopServer(): void {
    localSendService.stop();
    this.isRunning = false;
    this.onStatusChange?.(false);
  }

  build() {
    Column() {
      // 状态卡片
      Row() {
        // 状态指示器
        Circle()
          .width(12)
          .height(12)
          .fill(this.isRunning ? '#52C41A' : '#FF4D4F')
          .margin({ right: 8 })
        
        Column() {
          Text(this.isRunning ? '服务运行中' : '服务已停止')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          
          if (this.isRunning && this.networkInfo) {
            Text(`${this.networkInfo.ip}:${this.networkInfo.port}`)
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        
        // 开关按钮
        Toggle({ type: ToggleType.Switch, isOn: this.isRunning })
          .selectedColor('#007DFF')
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.startServer();
            } else {
              this.stopServer();
            }
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F5F5F5')
      .borderRadius(8)
      
      // 详细信息
      if (this.isRunning && this.networkInfo) {
        Column() {
          this.InfoRow('设备别名', this.networkInfo.alias)
          this.InfoRow('本机 IP', this.networkInfo.ip)
          this.InfoRow('端口', this.networkInfo.port.toString())
          this.InfoRow('协议版本', this.networkInfo.version)
          this.InfoRow('多播组', this.networkInfo.multicastGroup)
          
          // 指纹（可折叠）
          Row() {
            Text('设备指纹')
              .fontSize(14)
              .fontColor('#666666')
            
            Blank()
            
            Text(this.networkInfo.fingerprint.substring(0, 16) + '...')
              .fontSize(12)
              .fontColor('#999999')
              .fontFamily('monospace')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
      
      Blank()
      
      Text(value)
        .fontSize(14)
        .fontColor('#333333')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}

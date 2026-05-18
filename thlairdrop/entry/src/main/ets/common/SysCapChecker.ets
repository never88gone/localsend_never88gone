/**
 * 系统能力检测工具
 * 用于检测设备是否支持特定的系统能力，实现优雅降级
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SysCapChecker';
const DOMAIN = 0x0000;

/**
 * 系统能力定义
 */
export class SysCap {
  // 媒体转码能力
  static readonly AV_TRANSCODER = 'SystemCapability.Multimedia.Media.AVTranscoder';
  // 分布式设备管理
  static readonly DEVICE_MANAGER = 'SystemCapability.DistributedHardware.DeviceManager';
  // 蓝牙核心
  static readonly BLUETOOTH_CORE = 'SystemCapability.Communication.Bluetooth.Core';
  // WiFi P2P
  static readonly WIFI_P2P = 'SystemCapability.Communication.WiFi.P2P';
  // 分布式键值存储
  static readonly KV_STORE = 'SystemCapability.DistributedDataManager.KVStore.Core';
  // 分布式数据对象
  static readonly DISTRIBUTED_OBJECT = 'SystemCapability.DistributedDataManager.DataObject.DistributedObject';
  // DRM核心
  static readonly DRM_CORE = 'SystemCapability.Multimedia.Drm.Core';
}

/**
 * 系统能力检测结果
 */
export interface SysCapCheckResult {
  sysCap: string;
  supported: boolean;
}

/**
 * 系统能力检测器
 */
export class SysCapChecker {
  private static instance: SysCapChecker;
  private checkResults: Map<string, boolean> = new Map();

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): SysCapChecker {
    if (!SysCapChecker.instance) {
      SysCapChecker.instance = new SysCapChecker();
    }
    return SysCapChecker.instance;
  }

  /**
   * 检测单个系统能力是否支持
   * @param sysCap 系统能力名称
   * @returns 是否支持
   */
  isSupported(sysCap: string): boolean {
    if (this.checkResults.has(sysCap)) {
      return this.checkResults.get(sysCap)!;
    }

    // 使用canIUse检测能力是否可用
    const supported = canIUse(sysCap);
    this.checkResults.set(sysCap, supported);

    if (!supported) {
      hilog.warn(DOMAIN, TAG, `SysCap not supported: ${sysCap}`);
    }

    return supported;
  }

  /**
   * 批量检测系统能力
   * @param sysCaps 系统能力数组
   * @returns 检测结果数组
   */
  checkMultiple(sysCaps: string[]): SysCapCheckResult[] {
    const results: SysCapCheckResult[] = [];
    sysCaps.forEach(sysCap => {
      const result: SysCapCheckResult = {
        sysCap: sysCap,
        supported: this.isSupported(sysCap)
      };
      results.push(result);
    });
    return results;
  }

  /**
   * 检测所有关键系统能力
   * @returns 检测结果Map
   */
  checkAllCritical(): Map<string, boolean> {
    const criticalSysCaps = [
      SysCap.AV_TRANSCODER,
      SysCap.DEVICE_MANAGER,
      SysCap.BLUETOOTH_CORE,
      SysCap.WIFI_P2P,
      SysCap.KV_STORE,
      SysCap.DISTRIBUTED_OBJECT,
      SysCap.DRM_CORE
    ];

    const results = new Map<string, boolean>();
    criticalSysCaps.forEach(sysCap => {
      results.set(sysCap, this.isSupported(sysCap));
    });

    return results;
  }

  /**
   * 打印所有检测结果
   */
  printCheckResults(): void {
    hilog.info(DOMAIN, TAG, '========== SysCap Check Results ==========');
    this.checkResults.forEach((supported, sysCap) => {
      hilog.info(DOMAIN, TAG, `${sysCap}: ${supported ? '✓ Supported' : '✗ Not Supported'}`);
    });
    hilog.info(DOMAIN, TAG, '==========================================');
  }

  /**
   * 获取不支持的系统能力列表
   * @returns 不支持的系统能力数组
   */
  getUnsupportedSysCaps(): string[] {
    const unsupported: string[] = [];
    this.checkResults.forEach((supported, sysCap) => {
      if (!supported) {
        unsupported.push(sysCap);
      }
    });
    return unsupported;
  }
}

/**
 * 全局系统能力检测函数
 * @param sysCap 系统能力名称
 * @returns 是否支持
 */
export function isSysCapSupported(sysCap: string): boolean {
  return SysCapChecker.getInstance().isSupported(sysCap);
}

/**
 * 在应用启动时检测关键系统能力
 */
export function checkCriticalSysCapsOnStartup(): void {
  const checker = SysCapChecker.getInstance();
  checker.checkAllCritical();
  checker.printCheckResults();

  const unsupported = checker.getUnsupportedSysCaps();
  if (unsupported.length > 0) {
    hilog.warn(DOMAIN, TAG, 
      `App running with limited functionality. ${unsupported.length} SysCaps not supported.`);
  } else {
    hilog.info(DOMAIN, TAG, 'All critical SysCaps are supported.');
  }
}

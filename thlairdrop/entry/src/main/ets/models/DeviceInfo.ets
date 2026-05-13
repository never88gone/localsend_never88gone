/**
 * 设备信息模型
 */
export interface DeviceInfo {
  alias: string;
  version?: string;
  deviceModel?: string;
  deviceType?: string;
  fingerprint?: string;
  port?: number;
  protocol?: string;
  download?: boolean;
  address?: string;
}

/**
 * 网络接口信息
 */
export interface NetworkInterface {
  name: string;
  ipv4: string;
  ipv6?: string;
}

export interface NetworkInfo {
  interfaces: NetworkInterface[];
}

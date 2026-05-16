import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

/**
 * 历史记录项结构
 */
export interface HistoryRecord {
  id: string;
  fileName: string;
  size: number;
  time: number; // 时间戳
  direction: 'send' | 'receive';
  deviceName: string;
  status: 'completed' | 'failed';
  filePath?: string;
}

/**
 * 传输历史管理服务
 */
export class HistoryService {
  private static instance: HistoryService | null = null;
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private readonly PREF_NAME = 'localsend_history';
  private readonly KEY_RECORDS = 'records';
  private readonly MAX_RECORDS = 200; // 最多保留 200 条

  private constructor() {}

  static getInstance(): HistoryService {
    if (!HistoryService.instance) {
      HistoryService.instance = new HistoryService();
    }
    return HistoryService.instance;
  }

  /**
   * 初始化
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, this.PREF_NAME);
      hilog.info(0x0000, 'HistoryService', 'History preferences initialized');
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to init history preferences: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 获取所有历史记录
   */
  async getAllRecords(): Promise<HistoryRecord[]> {
    if (!this.prefs) return [];
    try {
      const json = await this.prefs.get(this.KEY_RECORDS, '[]') as string;
      return JSON.parse(json) as HistoryRecord[];
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to get history records: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /**
   * 添加一条历史记录
   */
  async addRecord(record: HistoryRecord): Promise<void> {
    if (!this.prefs) return;
    try {
      let records = await this.getAllRecords();
      // 检查是否已存在（避免重复添加）
      const index = records.findIndex(r => r.id === record.id);
      if (index !== -1) {
        records[index] = record;
      } else {
        records.unshift(record); // 添加到开头
      }
      
      // 限制数量
      if (records.length > this.MAX_RECORDS) {
        records = records.slice(0, this.MAX_RECORDS);
      }

      await this.prefs.put(this.KEY_RECORDS, JSON.stringify(records));
      await this.prefs.flush();
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to add history record: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 删除一条历史记录
   */
  async deleteRecord(id: string): Promise<void> {
    if (!this.prefs) return;
    try {
      let records = await this.getAllRecords();
      records = records.filter(r => r.id !== id);
      await this.prefs.put(this.KEY_RECORDS, JSON.stringify(records));
      await this.prefs.flush();
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to delete history record: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 清除所有历史记录
   */
  async clearAll(): Promise<void> {
    if (!this.prefs) return;
    try {
      await this.prefs.put(this.KEY_RECORDS, '[]');
      await this.prefs.flush();
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to clear history records: ${JSON.stringify(e)}`);
    }
  }
}

export const historyService = HistoryService.getInstance();

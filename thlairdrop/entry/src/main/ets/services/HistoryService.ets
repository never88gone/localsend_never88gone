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
 * 传输历史管理服务（带内存缓存，避免 Preferences flush 阻塞主线程）
 *
 * 核心设计：
 * - 所有读操作直接从内存缓存 cachedRecords 返回，零磁盘 I/O
 * - 所有写操作先原地更新内存缓存，然后通过 scheduleFlush 延迟 200ms 异步写盘
 * - flush 期间若有新写入，标记 pendingFlush，flush 完成后再补一次 flush
 * - prefs.flush() 只在 setTimeout 的后台任务中调用，永远不会卡 UI 帧
 */
export class HistoryService {
  private static instance: HistoryService | null = null;
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private readonly PREF_NAME = 'localsend_history';
  private readonly KEY_RECORDS = 'records';
  private readonly MAX_RECORDS = 200; // 最多保留 200 条

  // 内存缓存
  private cachedRecords: HistoryRecord[] | null = null;
  // 防止并发写入的标记
  private isFlushing: boolean = false;
  // 待写入标记（flush 期间有新增，完成后再执行一次 flush）
  private pendingFlush: boolean = false;

  private constructor() {}

  static getInstance(): HistoryService {
    if (!HistoryService.instance) {
      HistoryService.instance = new HistoryService();
    }
    return HistoryService.instance;
  }

  /**
   * 初始化：打开 Preferences 并预加载全量数据到内存缓存
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, this.PREF_NAME);
      hilog.info(0x0000, 'HistoryService', 'History preferences initialized');
      // 预加载到内存缓存，此后所有读操作均从内存返回
      const json = await this.prefs.get(this.KEY_RECORDS, '[]') as string;
      this.cachedRecords = JSON.parse(json) as HistoryRecord[];
      hilog.info(0x0000, 'HistoryService', `Loaded ${this.cachedRecords.length} history records into cache`);
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to init history preferences: ${JSON.stringify(e)}`);
      this.cachedRecords = [];
    }
  }

  /**
   * 获取所有历史记录（直接从内存缓存返回，零 I/O）
   */
  async getAllRecords(): Promise<HistoryRecord[]> {
    if (this.cachedRecords !== null) {
      return this.cachedRecords.slice(); // 返回副本防止外部修改
    }
    // 兜底：缓存未初始化时从磁盘读取
    if (!this.prefs) return [];
    try {
      const json = await this.prefs.get(this.KEY_RECORDS, '[]') as string;
      this.cachedRecords = JSON.parse(json) as HistoryRecord[];
      return this.cachedRecords.slice();
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to get history records: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /**
   * 添加一条历史记录（先更新内存缓存，再后台异步 flush）
   */
  async addRecord(record: HistoryRecord): Promise<void> {
    this.upsertIntoCache([record]);
    this.scheduleFlush();
  }

  /**
   * 批量添加历史记录（先更新内存缓存，再后台异步 flush）
   */
  async addRecords(recordsList: HistoryRecord[]): Promise<void> {
    if (recordsList.length === 0) return;
    this.upsertIntoCache(recordsList);
    this.scheduleFlush();
  }

  /**
   * 删除一条历史记录
   */
  async deleteRecord(id: string): Promise<void> {
    if (this.cachedRecords !== null) {
      this.cachedRecords = this.cachedRecords.filter(r => r.id !== id);
    }
    this.scheduleFlush();
  }

  /**
   * 清除所有历史记录
   */
  async clearAll(): Promise<void> {
    this.cachedRecords = [];
    this.scheduleFlush();
  }

  // ─── 私有方法 ───────────────────────────────────────────────────

  /**
   * 将记录列表 upsert 进内存缓存
   */
  private upsertIntoCache(recordsList: HistoryRecord[]): void {
    if (this.cachedRecords === null) {
      this.cachedRecords = [];
    }
    for (const record of recordsList) {
      const index = this.cachedRecords.findIndex(r => r.id === record.id);
      if (index !== -1) {
        this.cachedRecords[index] = record;
      } else {
        this.cachedRecords.unshift(record);
      }
    }
    // 限制上限
    if (this.cachedRecords.length > this.MAX_RECORDS) {
      this.cachedRecords = this.cachedRecords.slice(0, this.MAX_RECORDS);
    }
  }

  /**
   * 调度一次后台 flush（防并发：flush 中则标记 pending）
   */
  private scheduleFlush(): void {
    if (this.isFlushing) {
      this.pendingFlush = true;
      return;
    }
    // 延迟 200ms，彻底与当前渲染帧解耦，不阻塞 UI
    setTimeout(() => {
      this.doFlush();
    }, 200);
  }

  private async doFlush(): Promise<void> {
    if (!this.prefs || this.cachedRecords === null) return;
    this.isFlushing = true;
    try {
      const json = JSON.stringify(this.cachedRecords);
      await this.prefs.put(this.KEY_RECORDS, json);
      await this.prefs.flush();
      hilog.info(0x0000, 'HistoryService', `Flushed ${this.cachedRecords.length} records to disk`);
    } catch (e) {
      hilog.error(0x0000, 'HistoryService', `Failed to flush history records: ${JSON.stringify(e)}`);
    } finally {
      this.isFlushing = false;
      if (this.pendingFlush) {
        this.pendingFlush = false;
        // 有积压的写入，再调度一次
        setTimeout(() => {
          this.doFlush();
        }, 200);
      }
    }
  }
}

export const historyService = HistoryService.getInstance();

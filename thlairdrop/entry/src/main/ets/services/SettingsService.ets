import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

// 设置数据结构
export interface AppSettings {
  theme: string; // 'system' | 'light' | 'dark' | 'black'
  colorTheme: string; // 'blue' | 'green' | etc.
  language: string; // 'zh' | 'en'
  animationEnabled: boolean;
  quickSaveMode: number; // 0: 关, 1: 收藏, 2: 开
  saveDir: string;
  port: number;
  encryptionEnabled: boolean;
  aliasName: string;
  favorites: string[]; // 收藏设备的指纹列表
}

// 默认设置
const DEFAULT_SETTINGS: AppSettings = {
  theme: 'light',
  colorTheme: 'blue',
  language: 'system', // 默认跟随系统
  animationEnabled: true,
  quickSaveMode: 0,
  saveDir: '下载',
  port: 53317,
  encryptionEnabled: true,
  aliasName: 'HarmonyOS 设备',
  favorites: []
};

// 主题变更回调类型
export type ThemeChangeCallback = (theme: string) => void;
export type ColorThemeChangeCallback = (color: string) => void;
export type LanguageChangeCallback = (language: string) => void;

/**
 * 设置管理服务
 * 负责持久化存储应用设置
 */
export class SettingsService {
  private static instance: SettingsService | null = null;
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  
  // 设置变更回调
  private onThemeChange: ThemeChangeCallback | null = null;
  private onColorThemeChange: ColorThemeChangeCallback | null = null;
  private onLanguageChange: LanguageChangeCallback | null = null;
  
  private constructor() {}
  
  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }
  
  // 初始化
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, 'localsend_settings');
      hilog.info(0x0000, 'SettingsService', 'Preferences initialized');
    } catch (e) {
      hilog.error(0x0000, 'SettingsService', `Failed to init preferences: ${JSON.stringify(e)}`);
    }
  }

  getContext(): common.UIAbilityContext | null {
    return this.context;
  }
  
  // 设置回调
  setThemeChangeCallback(callback: ThemeChangeCallback): void {
    this.onThemeChange = callback;
  }
  
  setColorThemeChangeCallback(callback: ColorThemeChangeCallback): void {
    this.onColorThemeChange = callback;
  }
  
  setLanguageChangeCallback(callback: LanguageChangeCallback): void {
    this.onLanguageChange = callback;
  }
  
  // 获取设置
  async getSettings(): Promise<AppSettings> {
    if (!this.prefs) {
      return DEFAULT_SETTINGS;
    }
    
    try {
      const theme = await this.prefs.get('theme', DEFAULT_SETTINGS.theme) as string;
      const colorTheme = await this.prefs.get('colorTheme', DEFAULT_SETTINGS.colorTheme) as string;
      const language = await this.prefs.get('language', DEFAULT_SETTINGS.language) as string;
      const animationEnabled = await this.prefs.get('animationEnabled', DEFAULT_SETTINGS.animationEnabled) as boolean;
      const quickSaveMode = await this.prefs.get('quickSaveMode', DEFAULT_SETTINGS.quickSaveMode) as number;
      const saveDir = await this.prefs.get('saveDir', DEFAULT_SETTINGS.saveDir) as string;
      const port = await this.prefs.get('port', DEFAULT_SETTINGS.port) as number;
      const encryptionEnabled = await this.prefs.get('encryptionEnabled', DEFAULT_SETTINGS.encryptionEnabled) as boolean;
      const aliasName = await this.prefs.get('aliasName', DEFAULT_SETTINGS.aliasName) as string;
      const favoritesJson = await this.prefs.get('favorites', '[]') as string;
      
      const settings: AppSettings = {
        theme: theme,
        colorTheme: colorTheme,
        language: language,
        animationEnabled: animationEnabled,
        quickSaveMode: quickSaveMode,
        saveDir: saveDir,
        port: port,
        encryptionEnabled: encryptionEnabled,
        aliasName: aliasName,
        favorites: JSON.parse(favoritesJson) as string[]
      };
      return settings;
    } catch (e) {
      hilog.error(0x0000, 'SettingsService', `Failed to get settings: ${JSON.stringify(e)}`);
      return DEFAULT_SETTINGS;
    }
  }

  /**
   * 切换收藏状态
   */
  async toggleFavorite(fingerprint: string): Promise<boolean> {
    const settings = await this.getSettings();
    const index = settings.favorites.indexOf(fingerprint);
    if (index === -1) {
      settings.favorites.push(fingerprint);
    } else {
      settings.favorites.splice(index, 1);
    }
    return await this.saveSetting('favorites', JSON.stringify(settings.favorites));
  }

  /**
   * 是否已收藏
   */
  async isFavorite(fingerprint: string): Promise<boolean> {
    const settings = await this.getSettings();
    return settings.favorites.indexOf(fingerprint) !== -1;
  }
  
  // 保存主题
  async setTheme(theme: string): Promise<boolean> {
    return await this.saveSetting('theme', theme);
  }
  
  // 保存主题色彩
  async setColorTheme(color: string): Promise<boolean> {
    return await this.saveSetting('colorTheme', color);
  }
  
  // 保存语言
  async setLanguage(language: string): Promise<boolean> {
    return await this.saveSetting('language', language);
  }
  
  // 保存动画开关
  async setAnimationEnabled(enabled: boolean): Promise<boolean> {
    return await this.saveSetting('animationEnabled', enabled);
  }
  
  // 保存快速保存模式
  async setQuickSaveMode(mode: number): Promise<boolean> {
    return await this.saveSetting('quickSaveMode', mode);
  }
  
  // 保存保存目录
  async setSaveDir(dir: string): Promise<boolean> {
    return await this.saveSetting('saveDir', dir);
  }
  
  // 保存端口
  async setPort(port: number): Promise<boolean> {
    if (port < 1024 || port > 65535) {
      hilog.error(0x0000, 'SettingsService', `Invalid port: ${port}`);
      return false;
    }
    return await this.saveSetting('port', port);
  }
  
  // 保存加密开关
  async setEncryptionEnabled(enabled: boolean): Promise<boolean> {
    return await this.saveSetting('encryptionEnabled', enabled);
  }
  
  // 保存别名
  async setAliasName(alias: string): Promise<boolean> {
    if (!alias || alias.trim().length === 0) {
      hilog.error(0x0000, 'SettingsService', 'Invalid alias: alias cannot be empty');
      return false;
    }
    return await this.saveSetting('aliasName', alias.trim());
  }
  
  // 通用保存设置
  private async saveSetting(key: string, value: string | number | boolean): Promise<boolean> {
    if (!this.prefs) {
      return false;
    }
    
    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
      hilog.info(0x0000, 'SettingsService', `Setting saved: ${key} = ${value}`);
      
      // 触发回调
      if (key === 'theme' && this.onThemeChange) {
        this.onThemeChange(value as string);
      } else if (key === 'colorTheme' && this.onColorThemeChange) {
        this.onColorThemeChange(value as string);
      } else if (key === 'language' && this.onLanguageChange) {
        this.onLanguageChange(value as string);
      }
      
      return true;
    } catch (e) {
      hilog.error(0x0000, 'SettingsService', `Failed to save setting: ${JSON.stringify(e)}`);
      return false;
    }
  }
  
  // 获取主题显示名称
  getThemeDisplayName(theme: string): string {
    if (theme === 'system') return '系统';
    if (theme === 'light') return '浅色';
    if (theme === 'dark') return '深色';
    return '系统';
  }
  
  // 获取语言显示名称
  getLanguageDisplayName(language: string): string {
    if (language === 'zh') return '中文';
    if (language === 'en') return 'English';
    return '中文';
  }
  
  // 获取快速保存模式显示名称
  getQuickSaveModeDisplayName(mode: number): string {
    if (mode === 0) return '关闭';
    if (mode === 1) return '收藏';
    if (mode === 2) return '开启';
    return '关闭';
  }
}

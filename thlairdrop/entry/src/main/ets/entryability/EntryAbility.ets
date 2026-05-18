import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ThemeManager } from '../utils/ThemeManager';
import { checkCriticalSysCapsOnStartup } from '../common/SysCapChecker';
import { SettingsService } from '../services/SettingsService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  // 设置初始化完成的Promise
  private settingsReady: Promise<void> | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 检测系统能力支持情况，实现优雅降级
    checkCriticalSysCapsOnStartup();
    
    try {
      // 设置跟随系统主题模式
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    
    // 初始化 ThemeManager 的系统主题状态
    ThemeManager.initSystemTheme(this.context);
    
    // 提前加载设置并应用到AppStorage（在页面加载前完成）
    this.settingsReady = this.preLoadSettings();
    
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /**
   * 提前加载设置并应用到AppStorage
   * 这样页面加载时主题就已经正确设置，避免闪烁
   */
  private async preLoadSettings(): Promise<void> {
    try {
      const settingsService = SettingsService.getInstance();
      await settingsService.init(this.context);
      const settings = await settingsService.getSettings();
      
      // 提前将主题设置应用到AppStorage
      AppStorage.setOrCreate('appTheme', settings.theme);
      AppStorage.setOrCreate('appColorTheme', settings.colorTheme);
      AppStorage.setOrCreate('appLanguage', settings.language);
      AppStorage.setOrCreate('appAnimationEnabled', settings.animationEnabled);
      AppStorage.setOrCreate('appQuickSaveMode', settings.quickSaveMode);
      AppStorage.setOrCreate('appSaveDir', settings.saveDir);
      AppStorage.setOrCreate('appPort', settings.port);
      AppStorage.setOrCreate('appAliasName', settings.aliasName);
      
      hilog.info(DOMAIN, 'testTag', 'Settings pre-loaded: theme=%{public}s, colorTheme=%{public}s', 
        settings.theme, settings.colorTheme);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to pre-load settings: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 等待设置加载完成后再加载页面，避免主题闪烁
    (async () => {
      if (this.settingsReady) {
        await this.settingsReady;
      }
      
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    })();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  // 监听系统配置变化（包括主题变化）
  onConfigurationUpdate(newConfig: Configuration): void {
    // 更新 ThemeManager 中的系统主题状态
    ThemeManager.updateSystemThemeFromMode(newConfig.colorMode ?? 0);
    
    // 如果当前是跟随系统模式，触发主题更新
    const currentTheme = AppStorage.get<string>('appTheme');
    if (currentTheme === 'system') {
      // 通过重新设置来触发 UI 刷新
      AppStorage.setOrCreate('appTheme', 'system');
    }
    
    hilog.info(DOMAIN, 'testTag', 'Configuration updated, colorMode: %{public}d', newConfig.colorMode ?? 0);
  }
}

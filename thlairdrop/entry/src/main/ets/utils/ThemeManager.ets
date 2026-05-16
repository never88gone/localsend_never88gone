import common from '@ohos.app.ability.common';

// 颜色映射接口
interface ColorMap {
  bg_primary: string;
  bg_secondary: string;
  text_primary: string;
  text_secondary: string;
  text_tertiary: string;
  accent: string;
  accent_bg: string;
  divider: string;
  success: string;
  success_bg: string;
  error: string;
  error_bg: string;
  warning: string;
  warning_bg: string;
  transparent: string;
}

export class ThemeManager {
  // 系统主题状态
  private static systemTheme: string = 'light';

  // 获取基础颜色映射（根据主题）
  private static getBaseColorMap(theme: string): ColorMap {
    if (theme === 'dark') {
      return {
        bg_primary: '#1A1A1A',
        bg_secondary: '#2C2C2C',
        text_primary: '#FFFFFF',
        text_secondary: '#CCCCCC',
        text_tertiary: '#999999',
        accent: '#3A9AFF',
        accent_bg: '#1A334D',
        divider: '#3D3D3D',
        success: '#81C784',
        success_bg: '#1B3D20',
        error: '#E57373',
        error_bg: '#4A1D1D',
        warning: '#FFB74D',
        warning_bg: '#4D331A',
        transparent: 'transparent'
      };
    } else if (theme === 'black') {
      return {
        bg_primary: '#000000',
        bg_secondary: '#121212',
        text_primary: '#FFFFFF',
        text_secondary: '#B3B3B3',
        text_tertiary: '#666666',
        accent: '#3A9AFF',
        accent_bg: '#0D1A26',
        divider: '#262626',
        success: '#81C784',
        success_bg: '#0D1F12',
        error: '#E57373',
        error_bg: '#2A0F0F',
        warning: '#FFB74D',
        warning_bg: '#2A1A0D',
        transparent: 'transparent'
      };
    } else {
      // light
      return {
        bg_primary: '#F1F3F5',
        bg_secondary: '#FFFFFF',
        text_primary: '#333333',
        text_secondary: '#666666',
        text_tertiary: '#999999',
        accent: '#007DFF',
        accent_bg: '#E5F3FF',
        divider: '#E5E5E5',
        success: '#4CAF50',
        success_bg: '#E8F5E9',
        error: '#F44336',
        error_bg: '#FFEBEE',
        warning: '#FF9800',
        warning_bg: '#FFF3E0',
        transparent: 'transparent'
      };
    }
  }

  // UI/UX Pro Max 调色盘定义 (12 色阶: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900)
  private static readonly PALETTES: Record<string, string[]> = {
    'blue': ['#EFF6FF', '#DBEAFE', '#BFDBFE', '#93C5FD', '#60A5FA', '#3B82F6', '#2563EB', '#1D4ED8', '#1E40AF', '#1E3A8A'],
    'green': ['#F0FDF4', '#DCFCE7', '#BBF7D0', '#86EFAC', '#4ADE80', '#22C55E', '#16A34A', '#15803D', '#166534', '#14532D'],
    'yellow': ['#FEFCE8', '#FEF9C3', '#FEF08A', '#FDE047', '#FACC15', '#EAB308', '#CA8A04', '#A16207', '#854D0E', '#713F12'],
    'orange': ['#FFF7ED', '#FFEDD5', '#FED7AA', '#FDBA74', '#FB923C', '#F97316', '#EA580C', '#C2410C', '#9A3412', '#7C2D12'],
    'red': ['#FEF2F2', '#FEE2E2', '#FECACA', '#FCA5A5', '#F87171', '#EF4444', '#DC2626', '#B91C1C', '#991B1B', '#7F1D1D'],
    'pink': ['#FDF2F8', '#FCE7F3', '#FBCFE8', '#F9A8D4', '#F472B6', '#EC4899', '#DB2777', '#BE185D', '#9D174D', '#831843'],
    'purple': ['#FAF5FF', '#F3E8FF', '#E9D5FF', '#D8B4FE', '#C084FC', '#A855F7', '#9333EA', '#7E22CE', '#6B21A8', '#581C87'],
    'teal': ['#F0FDFA', '#CCFBF1', '#99F6E4', '#5EEAD4', '#2DD4BF', '#14B8A6', '#0D9488', '#0F766E', '#115E59', '#134E4A']
  };

  // 获取颜色主题的 accent 值 (500色阶)
  private static getColorThemeAccent(colorTheme: string): string {
    const palette = ThemeManager.PALETTES[colorTheme] || ThemeManager.PALETTES['blue'];
    return palette[5]; // 500
  }

  // 获取颜色主题的 accent_bg 值 (50/100 或 800/900色阶)
  private static getColorThemeAccentBg(colorTheme: string, isDark: boolean): string {
    const palette = ThemeManager.PALETTES[colorTheme] || ThemeManager.PALETTES['blue'];
    if (isDark) {
      return palette[8]; // 800
    } else {
      return palette[1]; // 100
    }
  }

  // 初始化系统主题（从 context 获取）
  static initSystemTheme(context: common.UIAbilityContext): void {
    const config = context.config;
    if (config.colorMode === 1) { // ColorMode.COLOR_MODE_DARK = 1
      ThemeManager.systemTheme = 'dark';
    } else {
      ThemeManager.systemTheme = 'light';
    }
    // 初始化主题版本号
    if (!AppStorage.has('themeVersion')) {
      AppStorage.setOrCreate('themeVersion', 0);
    }
  }

  // 更新系统主题状态（供外部调用）
  static updateSystemThemeFromMode(colorMode: number): void {
    const newTheme = colorMode === 1 ? 'dark' : 'light';
    if (ThemeManager.systemTheme !== newTheme) {
      ThemeManager.systemTheme = newTheme;
      // 触发主题版本更新
      ThemeManager.incrementThemeVersion();
    }
  }

  // 增加主题版本号（触发 UI 刷新）
  static incrementThemeVersion(): void {
    const version = AppStorage.get<number>('themeVersion') || 0;
    AppStorage.setOrCreate('themeVersion', version + 1);
  }

  // 获取实际主题（处理 system 模式）
  private static getEffectiveTheme(): string {
    let theme = AppStorage.get<string>('appTheme') || 'system';
    if (theme === 'system') {
      theme = ThemeManager.systemTheme;
    }
    return theme;
  }

  // 获取颜色主题
  private static getColorTheme(): string {
    return AppStorage.get<string>('appColorTheme') || 'blue';
  }

  private static getColorValue(colorMap: ColorMap, key: string): string {
    switch (key) {
      case 'bg_primary':
        return colorMap.bg_primary;
      case 'bg_secondary':
        return colorMap.bg_secondary;
      case 'text_primary':
        return colorMap.text_primary;
      case 'text_secondary':
        return colorMap.text_secondary;
      case 'text_tertiary':
        return colorMap.text_tertiary;
      case 'accent':
        return colorMap.accent;
      case 'accent_bg':
        return colorMap.accent_bg;
      case 'divider':
        return colorMap.divider;
      case 'success':
        return colorMap.success;
      case 'success_bg':
        return colorMap.success_bg;
      case 'error':
        return colorMap.error;
      case 'error_bg':
        return colorMap.error_bg;
      case 'warning':
        return colorMap.warning;
      case 'warning_bg':
        return colorMap.warning_bg;
      case 'transparent':
        return colorMap.transparent;
      default:
        return '';
    }
  }

  static getColor(key: string): string {
    const theme = ThemeManager.getEffectiveTheme();
    const colorTheme = ThemeManager.getColorTheme();
    const isDark = theme === 'dark' || theme === 'black';
    
    // 获取基础颜色映射
    const colorMap = ThemeManager.getBaseColorMap(theme);
    
    // 应用颜色主题
    colorMap.accent = ThemeManager.getColorThemeAccent(colorTheme);
    colorMap.accent_bg = ThemeManager.getColorThemeAccentBg(colorTheme, isDark);
    
    const value = ThemeManager.getColorValue(colorMap, key);
    return value || ThemeManager.getColorValue(ThemeManager.getBaseColorMap('light'), key) || '#000000';
  }

  // 获取当前系统主题状态（供外部查询）
  static getSystemTheme(): string {
    return ThemeManager.systemTheme;
  }
}

// 响应式获取颜色（需要在组件中绑定 themeVersion）
export function gc(key: string, themeVersion?: number): string {
  // 触摸 themeVersion 以建立依赖关系
  if (themeVersion !== undefined) {
    // 使用 themeVersion 确保响应式更新
  }
  return ThemeManager.getColor(key);
}

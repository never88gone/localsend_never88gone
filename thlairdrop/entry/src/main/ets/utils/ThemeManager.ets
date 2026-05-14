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

interface ThemeColors {
  light: ColorMap;
  dark: ColorMap;
}

export class ThemeManager {
  private static colors: ThemeColors = {
    light: {
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
    },
    dark: {
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
    }
  };

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
    let theme = AppStorage.get<string>('appTheme') || 'system';
    if (theme === 'system') {
      theme = 'light';
    }
    const colorMap = theme === 'dark' ? ThemeManager.colors.dark : ThemeManager.colors.light;
    const value = ThemeManager.getColorValue(colorMap, key);
    return value || ThemeManager.getColorValue(ThemeManager.colors.light, key) || '#000000';
  }
}

export function gc(key: string): string {
  return ThemeManager.getColor(key);
}

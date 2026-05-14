// 语言字符串映射接口
interface StringMap {
  tab_receive: string;
  tab_send: string;
  tab_settings: string;
  history_title: string;
  device_alias: string;
  device_port: string;
  device_ip: string;
  quick_save: string;
  quick_save_off: string;
  quick_save_fav: string;
  quick_save_on: string;
  offline: string;
  pending_files: string;
  accept: string;
  reject: string;
  in_progress: string;
  cancel: string;
  retry: string;
  view: string;
  completed: string;
  failed: string;
  waiting: string;
  cancelled: string;
  select_files: string;
  clear: string;
  file: string;
  media: string;
  text: string;
  app: string;
  nearby_devices: string;
  scanning: string;
  no_devices: string;
  scan_hint: string;
  help: string;
  send_text_title: string;
  input_text_placeholder: string;
  confirm: string;
  theme_title: string;
  theme_system: string;
  theme_light: string;
  theme_dark: string;
  language_title: string;
  animation_title: string;
  general_settings: string;
  network_settings: string;
  receive_settings: string;
  save_dir: string;
  empty_history: string;
  change_alias: string;
  input_alias: string;
  change_port: string;
  input_port: string;
  about_title: string;
  app_name: string;
  copy_right: string;
}

interface LanguageStrings {
  zh: StringMap;
  en: StringMap;
}

export class I18nManager {
  private static strings: LanguageStrings = {
    zh: {
      tab_receive: '接收',
      tab_send: '发送',
      tab_settings: '设置',
      history_title: '传输历史',
      device_alias: '别名',
      device_port: '端口',
      device_ip: 'IP 地址',
      quick_save: '快速保存',
      quick_save_off: '关闭',
      quick_save_fav: '收藏',
      quick_save_on: '开启',
      offline: '离线',
      pending_files: '待接收文件',
      accept: '接收',
      reject: '拒绝',
      in_progress: '传输中',
      cancel: '取消',
      retry: '重试',
      view: '查看',
      completed: '已完成',
      failed: '失败',
      waiting: '等待中',
      cancelled: '已取消',
      select_files: '选择要发送的文件',
      clear: '清除',
      file: '文件',
      media: '媒体',
      text: '文本',
      app: '应用',
      nearby_devices: '附近设备',
      scanning: '正在扫描局域网设备...',
      no_devices: '未发现附近设备',
      scan_hint: '点击右上角按钮扫描',
      help: '帮助',
      send_text_title: '发送文本',
      input_text_placeholder: '输入要发送的文本...',
      confirm: '确定',
      theme_title: '主题',
      theme_system: '跟随系统',
      theme_light: '浅色模式',
      theme_dark: '深色模式',
      language_title: '语言',
      animation_title: '动画',
      general_settings: '常规',
      network_settings: '网络',
      receive_settings: '接收',
      save_dir: '保存目录',
      empty_history: '暂无记录',
      change_alias: '修改别名',
      input_alias: '请输入设备别名',
      change_port: '修改端口',
      input_port: '请输入端口号 (1024-65535)',
      about_title: '关于',
      app_name: '糖葫芦投送',
      copy_right: '© 2024 糖葫芦团队'
    },
    en: {
      tab_receive: 'Receive',
      tab_send: 'Send',
      tab_settings: 'Settings',
      history_title: 'History',
      device_alias: 'Alias',
      device_port: 'Port',
      device_ip: 'IP Address',
      quick_save: 'Quick Save',
      quick_save_off: 'Off',
      quick_save_fav: 'Favorites',
      quick_save_on: 'On',
      offline: 'Offline',
      pending_files: 'Pending Requests',
      accept: 'Accept',
      reject: 'Reject',
      in_progress: 'In Progress',
      cancel: 'Cancel',
      retry: 'Retry',
      view: 'View',
      completed: 'Completed',
      failed: 'Failed',
      waiting: 'Waiting',
      cancelled: 'Cancelled',
      select_files: 'Select Files',
      clear: 'Clear',
      file: 'Files',
      media: 'Media',
      text: 'Text',
      app: 'App',
      nearby_devices: 'Nearby Devices',
      scanning: 'Scanning network...',
      no_devices: 'No devices found',
      scan_hint: 'Tap top-right to scan',
      help: 'Help',
      send_text_title: 'Send Text',
      input_text_placeholder: 'Enter text to send...',
      confirm: 'Confirm',
      theme_title: 'Theme',
      theme_system: 'System',
      theme_light: 'Light',
      theme_dark: 'Dark',
      language_title: 'Language',
      animation_title: 'Animation',
      general_settings: 'General',
      network_settings: 'Network',
      receive_settings: 'Receive',
      save_dir: 'Save Directory',
      empty_history: 'No History',
      change_alias: 'Change Alias',
      input_alias: 'Enter alias',
      change_port: 'Change Port',
      input_port: 'Enter port (1024-65535)',
      about_title: 'About',
      app_name: 'LocalSend',
      copy_right: '© 2024 LocalSend Team'
    }
  };

  private static getStringValue(langMap: StringMap, key: string): string {
    switch (key) {
      case 'tab_receive':
        return langMap.tab_receive;
      case 'tab_send':
        return langMap.tab_send;
      case 'tab_settings':
        return langMap.tab_settings;
      case 'history_title':
        return langMap.history_title;
      case 'device_alias':
        return langMap.device_alias;
      case 'device_port':
        return langMap.device_port;
      case 'device_ip':
        return langMap.device_ip;
      case 'quick_save':
        return langMap.quick_save;
      case 'quick_save_off':
        return langMap.quick_save_off;
      case 'quick_save_fav':
        return langMap.quick_save_fav;
      case 'quick_save_on':
        return langMap.quick_save_on;
      case 'offline':
        return langMap.offline;
      case 'pending_files':
        return langMap.pending_files;
      case 'accept':
        return langMap.accept;
      case 'reject':
        return langMap.reject;
      case 'in_progress':
        return langMap.in_progress;
      case 'cancel':
        return langMap.cancel;
      case 'retry':
        return langMap.retry;
      case 'view':
        return langMap.view;
      case 'completed':
        return langMap.completed;
      case 'failed':
        return langMap.failed;
      case 'waiting':
        return langMap.waiting;
      case 'cancelled':
        return langMap.cancelled;
      case 'select_files':
        return langMap.select_files;
      case 'clear':
        return langMap.clear;
      case 'file':
        return langMap.file;
      case 'media':
        return langMap.media;
      case 'text':
        return langMap.text;
      case 'app':
        return langMap.app;
      case 'nearby_devices':
        return langMap.nearby_devices;
      case 'scanning':
        return langMap.scanning;
      case 'no_devices':
        return langMap.no_devices;
      case 'scan_hint':
        return langMap.scan_hint;
      case 'help':
        return langMap.help;
      case 'send_text_title':
        return langMap.send_text_title;
      case 'input_text_placeholder':
        return langMap.input_text_placeholder;
      case 'confirm':
        return langMap.confirm;
      case 'theme_title':
        return langMap.theme_title;
      case 'theme_system':
        return langMap.theme_system;
      case 'theme_light':
        return langMap.theme_light;
      case 'theme_dark':
        return langMap.theme_dark;
      case 'language_title':
        return langMap.language_title;
      case 'animation_title':
        return langMap.animation_title;
      case 'general_settings':
        return langMap.general_settings;
      case 'network_settings':
        return langMap.network_settings;
      case 'receive_settings':
        return langMap.receive_settings;
      case 'save_dir':
        return langMap.save_dir;
      case 'empty_history':
        return langMap.empty_history;
      case 'change_alias':
        return langMap.change_alias;
      case 'input_alias':
        return langMap.input_alias;
      case 'change_port':
        return langMap.change_port;
      case 'input_port':
        return langMap.input_port;
      case 'about_title':
        return langMap.about_title;
      case 'app_name':
        return langMap.app_name;
      case 'copy_right':
        return langMap.copy_right;
      default:
        return '';
    }
  }

  static getString(key: string): string {
    const lang = AppStorage.get<string>('appLanguage') || 'zh';
    const langMap = lang === 'en' ? I18nManager.strings.en : I18nManager.strings.zh;
    const value = I18nManager.getStringValue(langMap, key);
    return value || I18nManager.getStringValue(I18nManager.strings.zh, key) || key;
  }
}

export function t(key: string): string {
  return I18nManager.getString(key);
}

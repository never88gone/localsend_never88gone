import i18n from '@ohos.i18n';

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
  theme_black: string;
  color_title: string;
  color_blue: string;
  color_green: string;
  color_yellow: string;
  color_orange: string;
  color_red: string;
  color_pink: string;
  color_purple: string;
  color_teal: string;
  language_title: string;
  language_system: string;
  animation_title: string;
  general_settings: string;
  network_settings: string;
  receive_settings: string;
  save_dir: string;
  save_dir_download: string;
  save_dir_pictures: string;
  save_dir_documents: string;
  empty_history: string;
  change_alias: string;
  input_alias: string;
  change_port: string;
  input_port: string;
  pin_code: string;
  change_pin_code: string;
  input_pin_code: string;
  pin_code_disabled: string;
  random_generate: string;
  about_title: string;
  app_name: string;
  copy_right: string;
  privacy_policy: string;
  privacy_policy_title: string;
  privacy_policy_content: string;
  third_party: string;
  third_party_localsend_desc: string;
  third_party_ack_title: string;
  third_party_ack_content: string;
  contact_community: string;
  contact_github: string;
  contact_telegram: string;
  contact_email: string;
  contact_website: string;
  copied_toast: string;
  // 帮助页面
  app_intro_title: string;
  app_intro_content: string;
  how_to_send_title: string;
  how_to_send_content: string;
  how_to_receive_title: string;
  how_to_receive_content: string;
  notes_title: string;
  notes_content: string;
  // 接收相关
  receive_complete: string;
  receive_failed: string;
  receive_start: string;
  accept_failed: string;
  file_count: string;
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
      theme_black: '纯黑模式',
      color_title: '主题色',
      color_blue: '蓝色',
      color_green: '绿色',
      color_yellow: '黄色',
      color_orange: '橙色',
      color_red: '红色',
      color_pink: '粉色',
      color_purple: '紫色',
      color_teal: '青色',
      language_title: '语言',
      language_system: '跟随系统',
      animation_title: '动画',
      general_settings: '常规',
      network_settings: '网络',
      receive_settings: '接收',
      save_dir: '保存目录',
      save_dir_download: '下载',
      save_dir_pictures: '图片',
      save_dir_documents: '文档',
      empty_history: '暂无记录',
      change_alias: '修改别名',
      input_alias: '请输入设备别名',
      change_port: '修改端口',
      input_port: '请输入端口号 (1024-65535)',
      pin_code: 'PIN 校验码',
      change_pin_code: '修改 PIN 码',
      input_pin_code: '请输入新的 PIN 码(留空表示禁用)',
      pin_code_disabled: '未启用',
      random_generate: '随机生成',
      about_title: '关于',
      app_name: '糖葫芦投送',
      copy_right: '© 2026 铭研信息',
      privacy_policy: '隐私政策',
      privacy_policy_title: '隐私与安全声明',
      privacy_policy_content: '欢迎使用糖葫芦投送！\n\n本应用是一款【纯单机免服务器】的局域网点对点（P2P）文件与文本传输工具。为了保障您的知情权，在此向您说明：\n\n1. 纯单机运行，无云端收集：本应用不设任何云端服务器，您的所有文件、文本内容及传输记录，均仅在您本地的局域网内设备之间进行直连点对点传递。我们不会、也无法收集或上传您的任何个人隐私数据。\n\n2. 核心权限使用说明：\n• 局域网设备扫描与连接：为寻找并直连同一网络下的其他设备，应用会申请WLAN与网络连接状态权限。\n• 文件读取与写入：为允许您选择发送的文件，以及将接收到的文件保存到本地，应用会申请读取和写入媒体文件的权限。所有文件操作均在您的本地设备上执行。\n\n3. 纯净无广告：本应用不包含任何广告插件与第三方追踪组件，请您放心使用。\n\n我们非常重视您的安全。上述说明均针对本地直连点对点局域网传输所需的必然操作，请您放心使用。',
      third_party: '第三方组件',
      third_party_localsend_desc: '跨平台文件传输应用，基于 LocalSend 协议实现局域网设备发现和文件传输功能。',
      third_party_ack_title: '致谢',
      third_party_ack_content: '本项目基于 LocalSend 开源项目开发，感谢 LocalSend 团队的开源贡献。LocalSend 提供了跨设备文件传输的核心协议和实现思路。',
      contact_community: '联系与社区',
      contact_github: 'GitHub 仓库',
      contact_telegram: 'Telegram 频道',
      contact_email: '官方邮箱',
      contact_website: '官方网站',
      copied_toast: '已复制到剪贴板',
      // 帮助页面
      app_intro_title: '应用介绍',
      app_intro_content: '糖葫芦投送是一款跨平台的文件传输应用，支持在局域网内的设备之间快速传输文件、图片、视频和文本内容。无需互联网连接，保护您的隐私安全。',
      how_to_send_title: '如何发送文件',
      how_to_send_content: '1. 在发送页面选择要发送的文件类型（文件、媒体或文本）\n2. 选择要发送的具体文件或输入文本内容\n3. 等待扫描发现附近的设备\n4. 点击目标设备旁边的"发送"按钮\n5. 等待传输完成',
      how_to_receive_title: '如何接收文件',
      how_to_receive_content: '1. 确保接收功能已开启（接收页面顶部开关）\n2. 当有设备发送文件时，会收到接收请求\n3. 选择"接收"或"拒绝"\n4. 接收的文件会保存到设置的保存目录中',
      notes_title: '注意事项',
      notes_content: '• 所有设备需要连接到同一个局域网（WiFi）\n• 确保设备之间的网络可以互相访问\n• 大文件传输可能需要较长时间，请耐心等待\n• 如遇问题，请检查网络连接和防火墙设置',
      // 接收相关
      receive_complete: '文件接收完成！',
      receive_failed: '接收失败',
      receive_start: '开始接收文件...',
      accept_failed: '接受请求失败',
      file_count: '个文件'
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
      theme_black: 'Black',
      color_title: 'Accent Color',
      color_blue: 'Blue',
      color_green: 'Green',
      color_yellow: 'Yellow',
      color_orange: 'Orange',
      color_red: 'Red',
      color_pink: 'Pink',
      color_purple: 'Purple',
      color_teal: 'Teal',
      language_title: 'Language',
      language_system: 'System',
      animation_title: 'Animation',
      general_settings: 'General',
      network_settings: 'Network',
      receive_settings: 'Receive',
      save_dir: 'Save Directory',
      save_dir_download: 'Download',
      save_dir_pictures: 'Pictures',
      save_dir_documents: 'Documents',
      empty_history: 'No History',
      change_alias: 'Change Alias',
      input_alias: 'Enter alias',
      change_port: 'Change Port',
      input_port: 'Enter port (1024-65535)',
      pin_code: 'PIN Code',
      change_pin_code: 'Change PIN Code',
      input_pin_code: 'Enter new PIN code (leave empty to disable)',
      pin_code_disabled: 'Disabled',
      random_generate: 'Random',
      about_title: 'About',
      app_name: 'LocalSend',
      copy_right: '© 2026 Mingyan Info',
      privacy_policy: 'Privacy Policy',
      privacy_policy_title: 'Privacy & Security Statement',
      privacy_policy_content: 'Welcome to Tanghulu Share!\n\nThis app is a serverless local network peer-to-peer (P2P) file and text transfer tool. To ensure your right to know, we hereby explain:\n\n1. Serverless operation, no cloud collection: This app does not use any cloud servers. All your files, text content, and transfer records are only transmitted directly between your local devices on the same local network. We do not and cannot collect or upload any of your personal privacy data.\n\n2. Core permissions description:\n• Local network device scanning and connection: To find and directly connect to other devices on the same network, the app requests WLAN and network connection state permissions.\n• File read and write: To allow you to select files to send and save received files to local storage, the app requests permissions to read and write media files. All file operations are executed locally on your device.\n\n3. Ad-free: This app does not contain any ad plugins or third-party tracking components. Please feel free to use it.\n\nWe value your security. The above operations are necessary for local direct P2P transfer. Please feel free to use the app.',
      third_party: 'Third Party',
      third_party_localsend_desc: 'Cross-platform file transfer application, implementing local network device discovery and file transfer based on the LocalSend protocol.',
      third_party_ack_title: 'Acknowledgements',
      third_party_ack_content: 'This project is developed based on the open-source LocalSend project. We thank the LocalSend team for their open-source contributions. LocalSend provides the core protocol and implementation ideas for cross-device file transfer.',
      contact_community: 'Contact & Community',
      contact_github: 'GitHub Repository',
      contact_telegram: 'Telegram Channel',
      contact_email: 'Official Email',
      contact_website: 'Official Website',
      copied_toast: 'Copied to clipboard',
      // 帮助页面
      app_intro_title: 'App Introduction',
      app_intro_content: 'LocalSend is a cross-platform file transfer app that allows fast transfer of files, images, videos, and text between devices on the same local network. No internet connection required, protecting your privacy.',
      how_to_send_title: 'How to Send Files',
      how_to_send_content: '1. On the Send page, select the file type (File, Media, or Text)\n2. Choose specific files or enter text content\n3. Wait for nearby devices to be discovered\n4. Click the "Send" button next to the target device\n5. Wait for the transfer to complete',
      how_to_receive_title: 'How to Receive Files',
      how_to_receive_content: '1. Ensure receiving is enabled (toggle on the Receive page)\n2. When a device sends files, you will receive a request\n3. Choose "Accept" or "Reject"\n4. Received files will be saved to the configured directory',
      notes_title: 'Notes',
      notes_content: '• All devices must be connected to the same local network (WiFi)\n• Ensure devices can communicate with each other on the network\n• Large files may take longer to transfer, please be patient\n• If issues occur, check network connection and firewall settings',
      // 接收相关
      receive_complete: 'File received!',
      receive_failed: 'Receive failed',
      receive_start: 'Starting receive...',
      accept_failed: 'Accept failed',
      file_count: 'files'
    }
  };

  private static getStringValue(langMap: StringMap, key: string): string {
    // 使用 Record 类型进行安全的索引访问
    const map = langMap as Object as Record<string, string>;
    return map[key] || '';
  }

  static getString(key: string, languageVersion?: number): string {
    // 如果 key 为空，直接返回
    if (!key) return '';
    
    // 建立 languageVersion 的响应式依赖
    // 当 languageVersion 变化时，会触发重新计算
    const _ = languageVersion;
    
    // 如果 key 本身就是我们要翻译的值之一（针对动态保存目录）
    const specialMap: Record<string, string> = {
      '下载': 'save_dir_download',
      '图片': 'save_dir_pictures',
      '文档': 'save_dir_documents',
      'Download': 'save_dir_download',
      'Pictures': 'save_dir_pictures',
      'Documents': 'save_dir_documents'
    };
    
    const lookupKey = specialMap[key] || key;
    
    let lang = AppStorage.get<string>('appLanguage') || 'system';
    if (lang === 'system') {
      const systemLang = i18n.System.getSystemLanguage();
      lang = systemLang.startsWith('zh') ? 'zh' : 'en';
    }
    
    const langMap = lang === 'en' ? I18nManager.strings.en : I18nManager.strings.zh;
    const value = I18nManager.getStringValue(langMap, lookupKey);
    
    // 如果找不到翻译，返回 key 本身或从中文映射中查找
    if (!value) {
      return I18nManager.getStringValue(I18nManager.strings.zh, lookupKey) || key;
    }
    return value;
  }

  // 增加语言版本号，触发 UI 刷新
  static incrementLanguageVersion(): void {
    const current = AppStorage.get<number>('languageVersion') || 0;
    AppStorage.setOrCreate('languageVersion', current + 1);
  }

  // 初始化
  static init(): void {
    if (!AppStorage.has('languageVersion')) {
      AppStorage.setOrCreate('languageVersion', 0);
    }
  }
}

export function t(key: string, languageVersion?: number): string {
  return I18nManager.getString(key, languageVersion);
}

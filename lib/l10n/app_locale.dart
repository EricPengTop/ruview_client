import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ws_service.dart';

enum AppLocale { zh, en }

class AppStrings {
  final AppLocale locale;
  AppStrings(this.locale);

  static const _zh = {
    'app_title': 'RuView 客户端',
    'tab_overview': '概览',
    'tab_vitals': '体征',
    'tab_pose': '姿态',
    'tab_zones': '区域',
    'tab_alerts': '告警',
    'tab_security': '安全',
    'connect': '连接',
    'disconnect': '断开连接',
    'connected': '已连接',
    'not_connected': '未连接',
    'settings': '设置',
    'debug': '开发者工具',
    'server_connection': '服务器连接',
    'server_info': '服务器信息',
    'host': '主机地址',
    'port': '端口',
    'alert_log': '告警日志',
    'alert_rules': '告警规则',
    'privacy': '隐私',
    'privacy_mode': '隐私模式',
    'privacy_desc': '隐藏心率/呼吸率等生物特征数据',
    'mqtt': 'MQTT 语义状态',
    'mqtt_connect': 'MQTT 连接',
    'appearance': '外观',
    'dark_mode': '暗色模式',
    'dark_mode_desc': '切换深色/浅色主题',
    'language': '语言',
    'about': '关于',
    'total_alerts': '条',
    'clear_all': '清空',
    'mark_read': '全部已读',
    'not_connected_msg': '未连接',
    'wait_data': '等待数据...',
    'pause': '暂停中',
    'realtime': '实时',
    'export_csv': '导出 CSV',
    'health_report': '健康报告',
    'security_status_ok': '系统运行正常',
    'security_status_monitor': '监控中',
    'zone_overview': '区域概览',
    'edit_zones': '编辑区域',
    'no_zones': '暂无自定义区域',
    'add_zone_hint': '点击"编辑区域"开始划定',
    'poses_wait': '等待姿态数据...',
    'presence': '人体存在',
    'motion': '运动状态',
    'signal_quality': '信号质量',
    'person_count': '人数',
    'no_messages': '暂无消息，点击连接开始',
    'hr_high': '心率上限',
    'hr_low': '心率下限',
    'br_high': '呼吸上限',
    'br_low': '呼吸下限',
  };

  static const _en = {
    'app_title': 'RuView Client',
    'tab_overview': 'Overview',
    'tab_vitals': 'Vitals',
    'tab_pose': 'Pose',
    'tab_zones': 'Zones',
    'tab_alerts': 'Alerts',
    'tab_security': 'Security',
    'connect': 'Connect',
    'disconnect': 'Disconnect',
    'connected': 'Connected',
    'not_connected': 'Not Connected',
    'settings': 'Settings',
    'debug': 'Dev Tools',
    'server_connection': 'Server Connection',
    'server_info': 'Server Info',
    'host': 'Host',
    'port': 'Port',
    'alert_log': 'Alert Log',
    'alert_rules': 'Alert Rules',
    'privacy': 'Privacy',
    'privacy_mode': 'Privacy Mode',
    'privacy_desc': 'Hide heart rate and breathing rate data',
    'mqtt': 'MQTT Semantic',
    'mqtt_connect': 'MQTT Connection',
    'appearance': 'Appearance',
    'dark_mode': 'Dark Mode',
    'dark_mode_desc': 'Switch between dark and light theme',
    'language': 'Language',
    'about': 'About',
    'total_alerts': 'items',
    'clear_all': 'Clear All',
    'mark_read': 'Mark Read',
    'not_connected_msg': 'Not Connected',
    'wait_data': 'Waiting for data...',
    'pause': 'Paused',
    'realtime': 'Live',
    'export_csv': 'Export CSV',
    'health_report': 'Health Report',
    'security_status_ok': 'System Normal',
    'security_status_monitor': 'Monitoring',
    'zone_overview': 'Zone Overview',
    'edit_zones': 'Edit Zones',
    'no_zones': 'No custom zones',
    'add_zone_hint': 'Tap "Edit Zones" to start',
    'poses_wait': 'Waiting for pose data...',
    'presence': 'Presence',
    'motion': 'Motion',
    'signal_quality': 'Signal Quality',
    'person_count': 'Count',
    'no_messages': 'No messages. Press Connect.',
    'hr_high': 'HR Max',
    'hr_low': 'HR Min',
    'br_high': 'BR Max',
    'br_low': 'BR Min',
  };

  String getString(String key) {
    final map = locale == AppLocale.zh ? _zh : _en;
    return map[key] ?? key;
  }
}

final appStringsProvider = Provider<AppStrings>((ref) {
  final state = ref.watch(appStateProvider.select((s) => s.locale));
  return AppStrings(state == 'en' ? AppLocale.en : AppLocale.zh);
});

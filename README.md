# RuView Client

RuView WiFi 感知 Flutter 桌面客户端 —— 实时接收并可视化 RuView 无摄像头人体感知数据。

## 功能

| 功能 | 说明 |
|------|------|
| **实时感知** | WebSocket 连接 RuView 服务，接收人体存在/心率/呼吸/运动/CSI 信号数据 |
| **概览仪表盘** | 人体存在大横幅 + 人数/运动/信号质量/RSSI 指标卡片 + 目标列表 |
| **生命体征** | 心率/呼吸率实时折线图，支持暂停回放拖动时间线，CSV 导出，健康报告 |
| **人体姿态** | COCO 17 关节骨架实时绘制，双指缩放，点击查看关键点详情 |
| **区域监控** | 自定义多边形区域编辑（热力图+传感器+人体坐标+信号场），自动碰撞检测 |
| **告警中心** | 5+ 种自动告警（人员进出/运动变化/人数变化/信号低/心率呼吸越界）+ 未读角标 |
| **安全监控** | 安全状态栏 + 安全日志列表 + 信号质量趋势图 + 紧急操作面板 |
| **设置页** | 服务器连接配置、告警规则阈值、隐私模式、MQTT 接入、暗色/亮色主题、中英双语 |
| **自动连接** | 启动时自动连接上次保存的 RuView 服务地址 |
| **桌面适配** | 鼠标拖动滚动、触控板、滚轮全支持 |
| **全中文化** | 所有 UI 文本中英双语 i18n，一键切换 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.44+ / Dart 3.12+ |
| 状态管理 | Riverpod (StateNotifierProvider) |
| 图表 | fl_chart |
| WebSocket | web_socket_channel |
| 通知 | flutter_local_notifications |
| 持久化 | shared_preferences |
| 国际化 | 自定义 AppStrings 字典 (无需 codegen) |

## 架构

```
lib/
├── main.dart                     # 入口 + RuViewApp (主题/语言/滚动配置)
├── models/
│   ├── models.dart               # barrel
│   ├── alert.dart                # AlertType 枚举 + Alert
│   ├── custom_zone.dart          # CustomZone
│   ├── pose_data.dart            # Keypoint + PoseDetection
│   ├── sensing_update.dart       # WifiNode + SignalField + SensingUpdate
│   └── vital_signs.dart          # VitalSigns + Classification + Features
├── services/
│   ├── ws_service.dart           # WebSocketService + AppState + AppStateNotifier
│   └── notification_service.dart # 本地推送通知
├── l10n/
│   └── app_locale.dart           # AppStrings 中英字典 + appStringsProvider
└── screens/
    ├── home_screen.dart           # 主页 (6 Tab 导航 + 自动连接)
    ├── dashboard_screen.dart      # 概览仪表盘
    ├── vitals_screen.dart         # 生命体征
    ├── pose_screen.dart           # 人体姿态
    ├── zones_screen.dart          # 区域监控
    ├── zone_editor_screen.dart    # 区域编辑器 (画布 + 热力图)
    ├── alerts_screen.dart         # 告警中心
    ├── security_screen.dart       # 安全监控
    ├── settings_screen.dart       # 设置页
    └── debug_screen.dart          # 开发者调试
```

## 快速开始

### 前置条件

- Flutter 3.44+ 
- RuView 服务运行中（Docker 或 ESP32）

### 启动 RuView（Docker）

```bash
docker run -d --name ruview \
  -p 3000:3000 -p 3001:3001 -p 5005:5005/udp \
  -e RUVIEW_ALLOW_UNAUTHENTICATED=1 \
  ruvnet/wifi-densepose:latest
```

### 运行客户端

```bash
cd ruview_client
flutter pub get
flutter run -d macos    # macOS
flutter run -d windows  # Windows (需配置)
flutter run -d android  # Android (需配置)
```

首次启动自动连接 `localhost:3001`，后续自动记忆配置。

## 数据流

```
RuView Docker (模拟CSI数据)
  │
  ▼ WebSocket (ws://host:3001/ws/sensing)
SensingUpdate (JSON)
  │
  ▼ ws_service.dart → SensingUpdate.fromJson()
AppState.latestUpdate
  │
  ▼ Riverpod Provider
6 Tab Screens (ConsumerWidget)
  │
  ▼ Widget 实时渲染
概览/体征/姿态/区域/告警/安全
```

## 依赖

```yaml
dependencies:
  web_socket_channel: ^3.0.2
  flutter_riverpod: ^2.6.1
  fl_chart: ^0.70.2
  flutter_local_notifications: ^18.0.0
  shared_preferences: ^2.5.3
```

## License

MIT

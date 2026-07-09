import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import 'notification_service.dart';

/// WebSocket 感知消息类型基类
sealed class SensingMessage {
  const SensingMessage();
}

/// 感知数据更新消息
class SensingUpdateMessage extends SensingMessage {
  /// 本帧 RuView 完整感知数据
  final SensingUpdate update;
  const SensingUpdateMessage(this.update);
}

/// WebSocket 连接状态
enum WsConnectionState { disconnected, connecting, connected }

extension WsConnectionStateLabel on WsConnectionState {
  /// 连接状态中文标签
  String get label {
    switch (this) {
      case WsConnectionState.disconnected: return '已断开';
      case WsConnectionState.connecting: return '连接中';
      case WsConnectionState.connected: return '已连接';
    }
  }
  /// 是否已连接
  bool get isConnected => this == WsConnectionState.connected;
}

/// WebSocket 连接管理器 (自动重连/心跳/消息流)
class WebSocketService {
  /// 服务端主机地址
  final String host;
  /// 服务端端口
  final int port;
  final int _maxReconnectAttempts = 10;
  final Duration _connectionTimeout = const Duration(seconds: 10);
  final Duration _heartbeatInterval = const Duration(seconds: 30);

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<dynamic>? _subscription;
  int _reconnectAttempts = 0;

  final _messageController = StreamController<SensingMessage>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// 感知消息流
  Stream<SensingMessage> get messages => _messageController.stream;
  /// 连接状态变化流
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;
  /// 错误信息流
  Stream<String> get errors => _errorController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;
  /// 当前连接状态
  WsConnectionState get state => _state;

  WebSocketService({required this.host, this.port = 3001});

  Uri get _wsUri => Uri.parse('ws://$host:$port/ws/sensing');

  /// 建立 WebSocket 连接 (自动重连/心跳)
  Future<void> connect() async {
    if (_state == WsConnectionState.connected || _state == WsConnectionState.connecting) return;
    _setState(WsConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(_wsUri)
        ..ready.timeout(_connectionTimeout, onTimeout: () => throw TimeoutException('Connection timeout'));
      await _channel!.ready;
      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
      _subscription = _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone, cancelOnError: false);
    } catch (e) {
      _errorController.add('连接失败: $e');
      _scheduleReconnect();
    }
  }

  /// 解析 WebSocket JSON 消息并分发
  void _onMessage(dynamic data) {
    try {
      if (data is! String) return;
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      if (type == 'sensing_update') {
        _messageController.add(SensingUpdateMessage(SensingUpdate.fromJson(json)));
      }
      _resetHeartbeat();
    } catch (e) {
      _errorController.add('解析错误: $e');
    }
  }

  void _onError(dynamic error) {
    _errorController.add('WebSocket错误: $error');
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    _cleanup();
    _scheduleReconnect();
  }

  /// 指数退避重连调度
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setState(WsConnectionState.disconnected);
      _errorController.add('已达最大重连次数');
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(milliseconds: (1000 * (1 << (_reconnectAttempts - 1))).clamp(1000, 30000));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  /// 30秒心跳保活
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _channel?.sink.add(jsonEncode({'type': 'ping'})));
  }

  /// 收到消息后重置心跳倒计时
  void _resetHeartbeat() {
    _heartbeatTimer?.cancel();
    _startHeartbeat();
  }

  /// 更新连接状态并通知监听者
  void _setState(WsConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  /// 清理连接资源
  void _cleanup() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// 主动断开连接
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _cleanup();
    _setState(WsConnectionState.disconnected);
  }

  /// 销毁所有资源
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
    await _errorController.close();
  }
}

/// 单帧生命体征记录 (用于历史折线图)
class VitalsRecord {
  /// 采集时间
  final DateTime time;
  /// 心率 bpm
  final double heartRate;
  /// 呼吸率 bpm
  final double breathingRate;
  /// 心率检测置信度 0-1
  final double hrConfidence;
  /// 呼吸检测置信度 0-1
  final double brConfidence;
  /// 信号质量 0-1
  final double signalQuality;

  const VitalsRecord({
    required this.time,
    required this.heartRate,
    required this.breathingRate,
    required this.hrConfidence,
    required this.brConfidence,
    required this.signalQuality,
  });
}

/// 应用全局状态 (连接/感知/告警/设置/主题/区域等)
class AppState {
  /// WebSocket 连接状态
  final WsConnectionState connectionState;
  /// 最新一帧 RuView 感知数据
  final SensingUpdate? latestUpdate;
  /// 调试日志列表
  final List<String> log;
  /// 最近一次错误信息
  final String? lastError;
  /// 已接收消息计数
  final int msgCount;
  /// 生命体征历史 (最近60帧)
  final List<VitalsRecord> vitalsHistory;
  /// 告警事件列表
  final List<Alert> alerts;
  /// 未读告警数 (Badge角标)
  final int unreadAlertCount;
  /// 是否暗色主题
  final bool isDarkMode;
  /// 体征图是否暂停
  final bool isPaused;
  /// 体征图暂停进度索引
  final int pausedIndex;
  /// 是否隐私模式 (隐藏生物特征)
  final bool isPrivacyMode;
  /// 心率告警上限 bpm
  final double hrMax;
  /// 心率告警下限 bpm
  final double hrMin;
  /// 呼吸告警上限 bpm
  final double brMax;
  /// 呼吸告警下限 bpm
  final double brMin;
  /// 用户自定义监控区域
  final List<CustomZone> customZones;
  /// 当前有人占用的区域 ID 列表
  final List<String> occupiedZoneIds;
  /// 界面语言 (zh/en)
  final String locale;
  /// 当前导航 Tab 索引
  final int currentTabIndex;

  const AppState({
    this.connectionState = WsConnectionState.disconnected,
    this.latestUpdate,
    this.log = const [],
    this.lastError,
    this.msgCount = 0,
    this.vitalsHistory = const [],
    this.alerts = const [],
    this.unreadAlertCount = 0,
    this.isDarkMode = true,
    this.isPaused = false,
    this.pausedIndex = 0,
    this.isPrivacyMode = false,
    this.hrMax = 120,
    this.hrMin = 40,
    this.brMax = 25,
    this.brMin = 5,
    this.customZones = const [],
    this.occupiedZoneIds = const [],
    this.locale = 'zh',
    this.currentTabIndex = 0,
  });

  /// 不可变拷贝更新 (传入字段替换对应值)
  AppState copyWith({
    WsConnectionState? connectionState,
    SensingUpdate? latestUpdate,
    List<String>? log,
    String? lastError,
    int? msgCount,
    List<VitalsRecord>? vitalsHistory,
    List<Alert>? alerts,
    int? unreadAlertCount,
    bool? isDarkMode,
    bool? isPaused,
    int? pausedIndex,
    bool? isPrivacyMode,
    double? hrMax,
    double? hrMin,
    double? brMax,
    double? brMin,
    List<CustomZone>? customZones,
    List<String>? occupiedZoneIds,
    String? locale,
    int? currentTabIndex,
  }) => AppState(
        connectionState: connectionState ?? this.connectionState,
        latestUpdate: latestUpdate ?? this.latestUpdate,
        log: log ?? this.log,
        lastError: lastError ?? this.lastError,
        msgCount: msgCount ?? this.msgCount,
        vitalsHistory: vitalsHistory ?? this.vitalsHistory,
        alerts: alerts ?? this.alerts,
        unreadAlertCount: unreadAlertCount ?? this.unreadAlertCount,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        isPaused: isPaused ?? this.isPaused,
        pausedIndex: pausedIndex ?? this.pausedIndex,
        isPrivacyMode: isPrivacyMode ?? this.isPrivacyMode,
        hrMax: hrMax ?? this.hrMax,
        hrMin: hrMin ?? this.hrMin,
        brMax: brMax ?? this.brMax,
        brMin: brMin ?? this.brMin,
        customZones: customZones ?? this.customZones,
        occupiedZoneIds: occupiedZoneIds ?? this.occupiedZoneIds,
        locale: locale ?? this.locale,
        currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      );
}

/// 应用状态管理器 (Provider → UI 通知)
class AppStateNotifier extends StateNotifier<AppState> {
  /// WebSocket 服务实例
  WebSocketService? _ws;
  /// 消息流订阅
  StreamSubscription<SensingMessage>? _msgSub;
  /// 连接状态流订阅
  StreamSubscription<WsConnectionState>? _connSub;
  /// 错误流订阅
  StreamSubscription<String>? _errSub;

  AppStateNotifier() : super(const AppState());

  /// 连接 RuView 服务并开始接收数据
  void connect(String host, int port) {
    _ws?.dispose();
    _msgSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();

    _ws = WebSocketService(host: host, port: port);

    _connSub = _ws!.connectionState.listen((connState) {
      final line = '${DateTime.now().toIso8601String()} 连接状态: ${connState.label}';
      debugPrint('[RuView] $line');
      state = state.copyWith(connectionState: connState, log: [...state.log, line]);
      if (connState.isConnected) _saveConnection(host, port);
    });

    _errSub = _ws!.errors.listen((err) {
      final line = '${DateTime.now().toIso8601String()} 错误: $err';
      debugPrint('[RuView] $line');
      state = state.copyWith(lastError: err, log: [...state.log, line]);
    });

    _msgSub = _ws!.messages.listen((msg) {
      if (msg is SensingUpdateMessage) {
        final u = msg.update;
        final count = state.msgCount + 1;
        final now = DateTime.now();
        final ts = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
        final presence = u.classification.presence ? '有人' : '无人';
        final motion = _motionLabel(u.classification.motionLevel);
        final hr = u.vitalSigns.heartRateBpm;
        final br = u.vitalSigns.breathingRateBpm;
        final hrConf = u.vitalSigns.heartbeatConfidence;
        final brConf = u.vitalSigns.breathingConfidence;
        final signalQ = u.vitalSigns.signalQuality;
        final nPersons = u.estimatedPersons;
        final rssi = u.features.meanRssi;
        final classifierConf = u.classification.confidence;
        final tick = u.tick;

        final personDetails = u.persons.isNotEmpty
            ? u.persons.map((p) => '目标${p.trackId}(置信${(p.confidence * 100).toStringAsFixed(0)}%)').join(' ')
            : '-';

        final vitalsPart = state.isPrivacyMode
            ? 'HR/BR=已隐藏'
            : '心率=${hr.toStringAsFixed(1)}bpm(可信度${(hrConf * 100).toStringAsFixed(0)}%) 呼吸率=${br.toStringAsFixed(1)}bpm(可信度${(brConf * 100).toStringAsFixed(0)}%)';

        final line = '#$count | $ts | t=$tick | $presence $motion (分类置信${(classifierConf * 100).toStringAsFixed(0)}%) | $vitalsPart | 信号质量=${(signalQ * 100).toStringAsFixed(0)}% | 人数=$nPersons [$personDetails] | RSSI=${rssi.toStringAsFixed(0)}dBm';
        debugPrint('[RuView] $line');

        // 追加生命体征历史 (上限60帧)
        final history = [...state.vitalsHistory, VitalsRecord(time: now, heartRate: hr, breathingRate: br, hrConfidence: hrConf, brConfidence: brConf, signalQuality: signalQ)];
        if (history.length > 60) history.removeAt(0);

        // 检测告警事件
        final prev = state.latestUpdate;
        final newAlerts = _detectAlerts(prev, u, now);
        final totalAlerts = [...state.alerts, ...newAlerts];
        if (totalAlerts.length > 200) totalAlerts.removeRange(0, totalAlerts.length - 200);

        final pausedIndex = state.isPaused ? state.pausedIndex : history.length - 1;
        final newLog = [...state.log, line];
        if (newLog.length > 500) newLog.removeRange(0, newLog.length - 500);

        // 区域占用碰撞检测
        List<String> occupiedIds = state.occupiedZoneIds;
        if (state.customZones.isNotEmpty && u.persons.isNotEmpty) {
          occupiedIds = _computeOccupiedZones(state.customZones, u.persons);
        } else {
          occupiedIds = const [];
        }

        state = state.copyWith(
          latestUpdate: u, msgCount: count, log: newLog,
          vitalsHistory: state.isPaused ? null : history,
          alerts: totalAlerts,
          unreadAlertCount: state.currentTabIndex == 4 ? state.unreadAlertCount : state.unreadAlertCount + newAlerts.length,
          pausedIndex: pausedIndex, occupiedZoneIds: occupiedIds,
        );

        // 告警通知 (系统推送)
        for (final alert in newAlerts) {
          debugPrint('[RuView] 🔔 ${alert.type.label}: ${alert.type.description}');
          if (alert.type == AlertType.presenceAppeared ||
              alert.type == AlertType.presenceDisappeared ||
              alert.type == AlertType.signalLow ||
              alert.type == AlertType.hrHigh ||
              alert.type == AlertType.brLow) {
            NotificationService.show(alert.type.label, alert.type.description);
          }
        }
      }
    });

    _ws!.connect();
  }

  /// 主动断开连接
  void disconnect() => _ws?.disconnect();

  /// 持久化保存连接信息到本地
  void _saveConnection(String host, int port) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ruview_host', host);
      prefs.setInt('ruview_port', port);
    });
  }

  /// 启动时自动连接上次保存的服务
  Future<void> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('ruview_host') ?? 'localhost';
    final port = prefs.getInt('ruview_port') ?? 3001;
    connect(host, port);
  }

  /// 清空调试日志
  void clearLog() => state = state.copyWith(log: [], msgCount: 0);

  /// 运动状态 → 中文标签
  String _motionLabel(String level) {
    switch (level) {
      case 'present_still': return '静止';
      case 'present_moving': return '运动中';
      case 'absent': return '无人';
      default: return level;
    }
  }

  /// 对比前后两帧检测告警事件
  List<Alert> _detectAlerts(SensingUpdate? prev, SensingUpdate curr, DateTime now) {
    final alerts = <Alert>[];
    if (prev == null) return alerts;

    if (prev.classification.presence != curr.classification.presence) {
      if (curr.classification.presence) {
        alerts.add(Alert(type: AlertType.presenceAppeared, time: now, details: '检测到${curr.estimatedPersons}人'));
      } else {
        alerts.add(Alert(type: AlertType.presenceDisappeared, time: now));
      }
    }
    if (prev.classification.motionLevel != curr.classification.motionLevel) {
      if (curr.classification.motionLevel == 'present_moving') {
        alerts.add(Alert(type: AlertType.motionStarted, time: now));
      } else if (curr.classification.motionLevel == 'present_still') {
        alerts.add(Alert(type: AlertType.motionStopped, time: now));
      }
    }
    if (prev.estimatedPersons != curr.estimatedPersons) {
      alerts.add(Alert(type: AlertType.personCountChanged, time: now, details: '${prev.estimatedPersons}人 → ${curr.estimatedPersons}人'));
    }
    if (curr.vitalSigns.signalQuality < 0.3 && prev.vitalSigns.signalQuality >= 0.3) {
      alerts.add(Alert(type: AlertType.signalLow, time: now, details: '当前${(curr.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%'));
    }

    // 自定义阈值告警
    final hr = curr.vitalSigns.heartRateBpm;
    final br = curr.vitalSigns.breathingRateBpm;
    final r = state;
    if (hr > r.hrMax && prev.vitalSigns.heartRateBpm <= r.hrMax) alerts.add(Alert(type: AlertType.hrHigh, time: now, details: '${hr.toStringAsFixed(1)} bpm > ${r.hrMax.toStringAsFixed(0)} bpm'));
    if (hr < r.hrMin && prev.vitalSigns.heartRateBpm >= r.hrMin) alerts.add(Alert(type: AlertType.hrLow, time: now, details: '${hr.toStringAsFixed(1)} bpm < ${r.hrMin.toStringAsFixed(0)} bpm'));
    if (br > r.brMax && prev.vitalSigns.breathingRateBpm <= r.brMax) alerts.add(Alert(type: AlertType.brHigh, time: now, details: '${br.toStringAsFixed(1)} bpm > ${r.brMax.toStringAsFixed(0)} bpm'));
    if (br < r.brMin && prev.vitalSigns.breathingRateBpm >= r.brMin) alerts.add(Alert(type: AlertType.brLow, time: now, details: '${br.toStringAsFixed(1)} bpm < ${r.brMin.toStringAsFixed(0)} bpm'));

    return alerts;
  }

  /// 人体 XY 坐标是否落入自定义区域多边形内
  List<String> _computeOccupiedZones(List<CustomZone> zones, List<PoseDetection> persons) {
    final occupied = <String>[];
    for (final zone in zones) {
      for (final person in persons) {
        final px = person.posX * 50 + 200;
        final py = person.posY * 50 + 200;
        if (_isPointInPolygon(Offset(px, py), zone.points)) {
          occupied.add(zone.id);
          break;
        }
      }
    }
    return occupied;
  }

  /// 射线法点是否在多边形内
  bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.dy > point.dy) != (b.dy > point.dy)) {
        final intersectX = (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
        if (point.dx < intersectX) intersections++;
      }
    }
    return intersections.isOdd;
  }

  /// 标记所有告警为已读
  void markAlertsRead() => state = state.copyWith(unreadAlertCount: 0);
  /// 清空所有告警
  void clearAlerts() => state = state.copyWith(alerts: [], unreadAlertCount: 0);
  /// 切换暗色/亮色主题
  void toggleTheme() => state = state.copyWith(isDarkMode: !state.isDarkMode);
  /// 切换隐私模式
  void togglePrivacyMode() => state = state.copyWith(isPrivacyMode: !state.isPrivacyMode);

  /// 设置心率告警上限
  void setHrMax(double v) => state = state.copyWith(hrMax: v);
  /// 设置心率告警下限
  void setHrMin(double v) => state = state.copyWith(hrMin: v);
  /// 设置呼吸告警上限
  void setBrMax(double v) => state = state.copyWith(brMax: v);
  /// 设置呼吸告警下限
  void setBrMin(double v) => state = state.copyWith(brMin: v);

  /// 添加自定义区域
  void addZone(CustomZone zone) => state = state.copyWith(customZones: [...state.customZones, zone]);
  /// 删除自定义区域
  void removeZone(String id) => state = state.copyWith(customZones: state.customZones.where((z) => z.id != id).toList());
  /// 切换界面语言
  void toggleLocale() => state = state.copyWith(locale: state.locale == 'zh' ? 'en' : 'zh');
  /// 记录当前 Tab 索引
  void setTabIndex(int index) => state = state.copyWith(currentTabIndex: index);
  /// 切换体征图暂停/播放
  void togglePause() {
    final paused = !state.isPaused;
    state = state.copyWith(isPaused: paused, pausedIndex: paused ? state.vitalsHistory.length - 1 : state.pausedIndex);
  }
  /// 跳转体征图历史帧
  void seekToFrame(int index) {
    if (index >= 0 && index < state.vitalsHistory.length) state = state.copyWith(pausedIndex: index);
  }

  @override
  void dispose() {
    _ws?.dispose();
    _msgSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();
    super.dispose();
  }
}

/// 全局应用状态 Provider
final appStateProvider = StateNotifierProvider.autoDispose<AppStateNotifier, AppState>((ref) => AppStateNotifier());

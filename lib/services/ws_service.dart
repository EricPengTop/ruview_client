import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';

sealed class SensingMessage {
  const SensingMessage();
}

class SensingUpdateMessage extends SensingMessage {
  final SensingUpdate update;

  const SensingUpdateMessage(this.update);
}

enum WsConnectionState { disconnected, connecting, connected }

extension WsConnectionStateLabel on WsConnectionState {
  String get label {
    switch (this) {
      case WsConnectionState.disconnected:
        return '已断开';
      case WsConnectionState.connecting:
        return '连接中';
      case WsConnectionState.connected:
        return '已连接';
    }
  }

  bool get isConnected => this == WsConnectionState.connected;
}

class WebSocketService {
  final String host;
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
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<SensingMessage> get messages => _messageController.stream;

  Stream<WsConnectionState> get connectionState =>
      _connectionStateController.stream;

  Stream<String> get errors => _errorController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;

  WsConnectionState get state => _state;

  WebSocketService({required this.host, this.port = 3001});

  Uri get _wsUri => Uri.parse('ws://$host:$port/ws/sensing');

  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(_wsUri)
        ..ready.timeout(
          _connectionTimeout,
          onTimeout: () {
            throw TimeoutException('Connection timeout');
          },
        );

      await _channel!.ready;

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _errorController.add('连接失败: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      if (data is! String) return;
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'sensing_update') {
        _messageController.add(
          SensingUpdateMessage(SensingUpdate.fromJson(json)),
        );
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

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setState(WsConnectionState.disconnected);
      _errorController.add('已达最大重连次数');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: (1000 * (1 << (_reconnectAttempts - 1))).clamp(1000, 30000),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _resetHeartbeat() {
    _heartbeatTimer?.cancel();
    _startHeartbeat();
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _cleanup();
    _setState(WsConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
    await _errorController.close();
  }
}

class VitalsRecord {
  final DateTime time;
  final double heartRate;
  final double breathingRate;
  final double hrConfidence;
  final double brConfidence;
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

class AppState {
  final WsConnectionState connectionState;
  final SensingUpdate? latestUpdate;
  final List<String> log;
  final String? lastError;
  final int msgCount;
  final List<VitalsRecord> vitalsHistory;
  final List<Alert> alerts;
  final int unreadAlertCount;
  final bool isDarkMode;
  final bool isPaused;
  final int pausedIndex;
  final bool isPrivacyMode;
  final bool mqttEnabled;
  final String mqttHost;
  final int mqttPort;
  final bool mqttConnected;
  final Map<String, String> semanticStates;
  final double hrMax;
  final double hrMin;
  final double brMax;
  final double brMin;
  final List<CustomZone> customZones;
  final String locale;

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
    this.mqttEnabled = false,
    this.mqttHost = 'localhost',
    this.mqttPort = 1883,
    this.mqttConnected = false,
    this.semanticStates = const {},
    this.hrMax = 120,
    this.hrMin = 40,
    this.brMax = 25,
    this.brMin = 5,
    this.customZones = const [],
    this.locale = 'zh',
  });

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
    bool? mqttEnabled,
    String? mqttHost,
    int? mqttPort,
    bool? mqttConnected,
    Map<String, String>? semanticStates,
    double? hrMax,
    double? hrMin,
    double? brMax,
    double? brMin,
    List<CustomZone>? customZones,
    String? locale,
  }) => AppState(
    connectionState: connectionState ?? this.connectionState,
    latestUpdate: latestUpdate ?? this.latestUpdate,
    log: log ?? this.log,
    lastError: lastError,
    msgCount: msgCount ?? this.msgCount,
    vitalsHistory: vitalsHistory ?? this.vitalsHistory,
    alerts: alerts ?? this.alerts,
    unreadAlertCount: unreadAlertCount ?? this.unreadAlertCount,
    isDarkMode: isDarkMode ?? this.isDarkMode,
    isPaused: isPaused ?? this.isPaused,
    pausedIndex: pausedIndex ?? this.pausedIndex,
    isPrivacyMode: isPrivacyMode ?? this.isPrivacyMode,
    mqttEnabled: mqttEnabled ?? this.mqttEnabled,
    mqttHost: mqttHost ?? this.mqttHost,
    mqttPort: mqttPort ?? this.mqttPort,
    mqttConnected: mqttConnected ?? this.mqttConnected,
    semanticStates: semanticStates ?? this.semanticStates,
    hrMax: hrMax ?? this.hrMax,
    hrMin: hrMin ?? this.hrMin,
    brMax: brMax ?? this.brMax,
    brMin: brMin ?? this.brMin,
    customZones: customZones ?? this.customZones,
    locale: locale ?? this.locale,
  );
}

class AppStateNotifier extends StateNotifier<AppState> {
  WebSocketService? _ws;
  StreamSubscription<SensingMessage>? _msgSub;
  StreamSubscription<WsConnectionState>? _connSub;
  StreamSubscription<String>? _errSub;
  MqttService? _mqtt;

  AppStateNotifier() : super(const AppState());

  void connect(String host, int port) {
    _ws?.dispose();
    _msgSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();

    _ws = WebSocketService(host: host, port: port);

    _connSub = _ws!.connectionState.listen((connState) {
      final line =
          '${DateTime.now().toIso8601String()} 连接状态: ${connState.label}';
      debugPrint('[RuView] $line');
      state = state.copyWith(
        connectionState: connState,
        log: [...state.log, line],
      );
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

        final ts =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}.'
            '${now.millisecond.toString().padLeft(3, '0')}';

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
            ? u.persons
                  .map(
                    (p) =>
                        '目标${p.trackId}(置信${(p.confidence * 100).toStringAsFixed(0)}%)',
                  )
                  .join(' ')
            : '-';

        final vitalsPart = state.isPrivacyMode
            ? 'HR/BR=已隐藏'
            : '心率=${hr.toStringAsFixed(1)}bpm(可信度${(hrConf * 100).toStringAsFixed(0)}%) '
                  '呼吸率=${br.toStringAsFixed(1)}bpm(可信度${(brConf * 100).toStringAsFixed(0)}%)';

        final line =
            '#$count | $ts | t=$tick | $presence $motion (分类置信${(classifierConf * 100).toStringAsFixed(0)}%) | '
            '$vitalsPart | '
            '信号质量=${(signalQ * 100).toStringAsFixed(0)}% | '
            '人数=$nPersons [$personDetails] | RSSI=${rssi.toStringAsFixed(0)}dBm';

        debugPrint('[RuView] $line');

        final history = [
          ...state.vitalsHistory,
          VitalsRecord(
            time: now,
            heartRate: hr,
            breathingRate: br,
            hrConfidence: hrConf,
            brConfidence: brConf,
            signalQuality: signalQ,
          ),
        ];
        if (history.length > 60) {
          history.removeAt(0);
        }

        final prev = state.latestUpdate;
        final newAlerts = _detectAlerts(prev, u, now);
        final totalAlerts = [...state.alerts, ...newAlerts];
        if (totalAlerts.length > 200) {
          totalAlerts.removeRange(0, totalAlerts.length - 200);
        }

        final pausedIndex = state.isPaused
            ? state.pausedIndex
            : history.length - 1;

        state = state.copyWith(
          latestUpdate: u,
          msgCount: count,
          log: [...state.log, line],
          vitalsHistory: state.isPaused ? null : history,
          alerts: totalAlerts,
          unreadAlertCount: state.unreadAlertCount + newAlerts.length,
          pausedIndex: pausedIndex,
        );

        for (final alert in newAlerts) {
          debugPrint(
            '[RuView] 🔔 ${alert.type.label}: ${alert.type.description}',
          );
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

  void disconnect() {
    _ws?.disconnect();
  }

  void clearLog() {
    state = state.copyWith(log: [], msgCount: 0);
  }

  String _motionLabel(String level) {
    switch (level) {
      case 'present_still':
        return '静止';
      case 'present_moving':
        return '运动中';
      case 'absent':
        return '无人';
      default:
        return level;
    }
  }

  List<Alert> _detectAlerts(
    SensingUpdate? prev,
    SensingUpdate curr,
    DateTime now,
  ) {
    final alerts = <Alert>[];

    if (prev == null) return alerts;

    // Presence change
    if (prev.classification.presence != curr.classification.presence) {
      if (curr.classification.presence) {
        alerts.add(
          Alert(
            type: AlertType.presenceAppeared,
            time: now,
            details: '检测到${curr.estimatedPersons}人',
          ),
        );
      } else {
        alerts.add(Alert(type: AlertType.presenceDisappeared, time: now));
      }
    }

    // Motion change
    if (prev.classification.motionLevel != curr.classification.motionLevel) {
      if (curr.classification.motionLevel == 'present_moving') {
        alerts.add(Alert(type: AlertType.motionStarted, time: now));
      } else if (curr.classification.motionLevel == 'present_still') {
        alerts.add(Alert(type: AlertType.motionStopped, time: now));
      }
    }

    // Person count change
    if (prev.estimatedPersons != curr.estimatedPersons) {
      alerts.add(
        Alert(
          type: AlertType.personCountChanged,
          time: now,
          details: '${prev.estimatedPersons}人 → ${curr.estimatedPersons}人',
        ),
      );
    }

    // Low signal quality (below 30%)
    if (curr.vitalSigns.signalQuality < 0.3 &&
        prev.vitalSigns.signalQuality >= 0.3) {
      alerts.add(
        Alert(
          type: AlertType.signalLow,
          time: now,
          details:
              '当前${(curr.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%',
        ),
      );
    }

    // Custom threshold alerts
    final hr = curr.vitalSigns.heartRateBpm;
    final br = curr.vitalSigns.breathingRateBpm;
    final r = state;

    if (hr > r.hrMax && prev.vitalSigns.heartRateBpm <= r.hrMax) {
      alerts.add(
        Alert(
          type: AlertType.hrHigh,
          time: now,
          details:
              '${hr.toStringAsFixed(1)} bpm > ${r.hrMax.toStringAsFixed(0)} bpm',
        ),
      );
    }
    if (hr < r.hrMin && prev.vitalSigns.heartRateBpm >= r.hrMin) {
      alerts.add(
        Alert(
          type: AlertType.hrLow,
          time: now,
          details:
              '${hr.toStringAsFixed(1)} bpm < ${r.hrMin.toStringAsFixed(0)} bpm',
        ),
      );
    }
    if (br > r.brMax && prev.vitalSigns.breathingRateBpm <= r.brMax) {
      alerts.add(
        Alert(
          type: AlertType.brHigh,
          time: now,
          details:
              '${br.toStringAsFixed(1)} bpm > ${r.brMax.toStringAsFixed(0)} bpm',
        ),
      );
    }
    if (br < r.brMin && prev.vitalSigns.breathingRateBpm >= r.brMin) {
      alerts.add(
        Alert(
          type: AlertType.brLow,
          time: now,
          details:
              '${br.toStringAsFixed(1)} bpm < ${r.brMin.toStringAsFixed(0)} bpm',
        ),
      );
    }

    return alerts;
  }

  void markAlertsRead() {
    state = state.copyWith(unreadAlertCount: 0);
  }

  void clearAlerts() {
    state = state.copyWith(alerts: [], unreadAlertCount: 0);
  }

  void toggleTheme() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void togglePrivacyMode() {
    state = state.copyWith(isPrivacyMode: !state.isPrivacyMode);
  }

  Future<void> toggleMqtt() async {
    if (state.mqttEnabled) {
      _mqtt?.disconnect();
      _mqtt = null;
      state = state.copyWith(mqttEnabled: false, mqttConnected: false);
    } else {
      state = state.copyWith(mqttEnabled: true);
      try {
        _mqtt = MqttService(
          host: state.mqttHost,
          port: state.mqttPort,
          onMessage: (topic, payload) {
            final key = topic.split('/').last;
            state = state.copyWith(
              semanticStates: {
                ...state.semanticStates,
                key: payload.toString(),
              },
            );
          },
        );
        await _mqtt!.connect();
        _mqtt!.subscribe('homeassistant/#');
        state = state.copyWith(mqttConnected: true);
      } catch (e) {
        state = state.copyWith(mqttEnabled: false, mqttConnected: false);
        _mqtt = null;
      }
    }
  }

  void updateMqttHost(String host) {
    state = state.copyWith(mqttHost: host);
  }

  void updateMqttPort(int port) {
    state = state.copyWith(mqttPort: port);
  }

  void setHrMax(double v) => state = state.copyWith(hrMax: v);

  void setHrMin(double v) => state = state.copyWith(hrMin: v);

  void setBrMax(double v) => state = state.copyWith(brMax: v);

  void setBrMin(double v) => state = state.copyWith(brMin: v);

  void addZone(CustomZone zone) {
    state = state.copyWith(customZones: [...state.customZones, zone]);
  }

  void removeZone(String id) {
    state = state.copyWith(
      customZones: state.customZones.where((z) => z.id != id).toList(),
    );
  }

  void toggleLocale() {
    state = state.copyWith(locale: state.locale == 'zh' ? 'en' : 'zh');
  }

  void togglePause() {
    final paused = !state.isPaused;
    state = state.copyWith(
      isPaused: paused,
      pausedIndex: paused ? state.vitalsHistory.length - 1 : state.pausedIndex,
    );
  }

  void seekToFrame(int index) {
    if (index >= 0 && index < state.vitalsHistory.length) {
      state = state.copyWith(pausedIndex: index);
    }
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

final appStateProvider =
    StateNotifierProvider.autoDispose<AppStateNotifier, AppState>(
      (ref) => AppStateNotifier(),
    );

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';
import 'debug_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '3001');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isConnected = state.connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('服务器连接'),
          _buildServerCard(notifier, isConnected, state),
          if (isConnected) ...[
            _section('服务器信息'),
            _buildServerInfo(state),
          ],
          _section('告警日志'),
          _buildAlertsCard(notifier, state),
          _section('隐私'),
          _buildPrivacyCard(notifier, state),
          _section('MQTT 语义状态'),
          _buildMqttCard(notifier, state),
          _section('外观'),
          _buildThemeCard(notifier, state),
          _section('关于'),
          _buildAboutCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500)),
      );

  Widget _infoRow(String label, String value) => ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(value,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        dense: true,
      );

  Widget _buildServerCard(
      AppStateNotifier notifier, bool isConnected, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.circle : Icons.circle_outlined,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(isConnected ? '已连接' : '未连接',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (isConnected && state.latestUpdate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '数据: ${state.latestUpdate!.classification.presence ? "有人" : "无人"}, ${state.latestUpdate!.vitalSigns.heartRateBpm.toStringAsFixed(0)}bpm',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () {
                    if (isConnected) {
                      notifier.disconnect();
                    } else {
                      notifier.connect(_hostController.text,
                          int.tryParse(_portController.text) ?? 3001);
                    }
                  },
                  child: Text(isConnected ? '断开' : '连接'),
                ),
              ],
            ),
            if (!isConnected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                    labelText: '主机地址',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                    labelText: '端口',
                    border: OutlineInputBorder(),
                    isDense: true),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanLocalhost(context),
                      icon: const Icon(Icons.dns, size: 16),
                      label: const Text('本机探测'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanNetwork(context),
                      icon: const Icon(Icons.wifi_find, size: 16),
                      label: const Text('局域网发现'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo(AppState state) {
    return Card(
      child: Column(
        children: [
          _infoRow('消息总数', '#${state.msgCount}'),
          if (state.latestUpdate != null) ...[
            const Divider(height: 1),
            _infoRow('服务端 Tick', 't=${state.latestUpdate!.tick}'),
            const Divider(height: 1),
            _infoRow('信号质量',
                '${(state.latestUpdate!.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%'),
            const Divider(height: 1),
            _infoRow('RSSI',
                '${state.latestUpdate!.features.meanRssi.toStringAsFixed(0)} dBm'),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsCard(AppStateNotifier notifier, AppState state) {
    final recentAlerts = state.alerts.reversed.take(3).toList();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Badge(
              isLabelVisible: state.unreadAlertCount > 0,
              label: Text(state.unreadAlertCount.toString()),
              child: const Icon(Icons.notifications_outlined),
            ),
            title: const Text('告警日志'),
            subtitle: Text('共 ${state.alerts.length} 条',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('告警日志')),
                        body: ListView.builder(
                          itemCount: state.alerts.reversed.length,
                          itemBuilder: (context, i) {
                            final a = state.alerts.reversed.toList()[i];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: a.type == AlertType.presenceAppeared
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : a.type == AlertType.presenceDisappeared
                                        ? Colors.grey.withValues(alpha: 0.2)
                                        : a.type == AlertType.signalLow
                                            ? Colors.red.withValues(alpha: 0.2)
                                            : Colors.orange.withValues(alpha: 0.2),
                                child: Icon(
                                  _alertIcon(a.type),
                                  size: 14,
                                  color: a.type == AlertType.presenceAppeared
                                      ? Colors.green
                                      : a.type == AlertType.signalLow
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ),
                              title: Text(a.type.label,
                                  style: const TextStyle(fontSize: 14)),
                              subtitle: Text(a.type.description,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              trailing: Text(
                                '${a.time.hour.toString().padLeft(2, '0')}:${a.time.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            );
                          },
                        ),
                      )),
            ),
          ),
          if (recentAlerts.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: recentAlerts.map((a) {
                  return Row(
                    children: [
                      Icon(_alertIcon(a.type), size: 12,
                          color: a.type == AlertType.signalLow ? Colors.red : Colors.orange),
                      const SizedBox(width: 6),
                      Text(a.type.label, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(a.type.description,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
          if (state.alerts.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => notifier.markAlertsRead(),
                    child: const Text('全部已读'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => notifier.clearAlerts(),
                    child: const Text('清空'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.presenceAppeared:
        return Icons.person_add;
      case AlertType.presenceDisappeared:
        return Icons.person_off;
      case AlertType.motionStarted:
        return Icons.directions_run;
      case AlertType.motionStopped:
        return Icons.airline_seat_flat;
      case AlertType.personCountChanged:
        return Icons.people;
      case AlertType.signalLow:
        return Icons.signal_cellular_alt;
    }
  }

  Widget _buildPrivacyCard(AppStateNotifier notifier, AppState state) {
    return Card(
      child: SwitchListTile(
        title: const Text('隐私模式'),
        subtitle: const Text('隐藏心率/呼吸率等生物特征数据'),
        value: state.isPrivacyMode,
        onChanged: (_) => notifier.togglePrivacyMode(),
        secondary: Icon(
          state.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMqttCard(AppStateNotifier notifier, AppState state) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('MQTT 连接'),
            subtitle: Text(state.mqttConnected ? '已连接' : '未启用',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            value: state.mqttEnabled,
            onChanged: (_) => notifier.toggleMqtt(),
            secondary: Icon(
              state.mqttConnected ? Icons.cloud_done : Icons.cloud_off,
              color: state.mqttConnected ? Colors.green : Colors.grey,
            ),
          ),
          if (!state.mqttConnected) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'MQTT 主机',
                          border: OutlineInputBorder(),
                          isDense: true),
                      controller:
                          TextEditingController(text: state.mqttHost),
                      onChanged: notifier.updateMqttHost,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: '端口',
                          border: OutlineInputBorder(),
                          isDense: true),
                      controller:
                          TextEditingController(text: '${state.mqttPort}'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final p = int.tryParse(v);
                        if (p != null) notifier.updateMqttPort(p);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.semanticStates.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: state.semanticStates.entries.map((e) {
                  return Chip(
                    label: Text(e.key, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeCard(AppStateNotifier notifier, AppState state) {
    return Card(
      child: SwitchListTile(
        title: const Text('暗色模式'),
        subtitle: const Text('切换深色/浅色主题'),
        value: state.isDarkMode,
        onChanged: (_) => notifier.toggleTheme(),
        secondary: Icon(
          state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _infoRow('应用名', 'RuView 客户端'),
          const Divider(height: 1),
          _infoRow('版本', '1.0.0'),
          const Divider(height: 1),
          _infoRow('数据源', 'RuView WiFi Sensing Server'),
          const Divider(height: 1),
          ListTile(
            title: const Text('开发者工具', style: TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            dense: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _scanLocalhost(BuildContext context) async {
  final found = <String>[];
  for (final port in [3000, 3001, 8765, 8000, 8080]) {
    try {
      final socket = await Socket.connect(
        'localhost',
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      found.add('$port');
    } catch (_) {}
  }

  if (context.mounted) {
    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本机未发现 RuView 服务')),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('本机发现'),
          content: Text('以下端口有服务响应: ${found.join(', ')}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }
}

Future<void> _scanNetwork(BuildContext context) async {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('局域网发现需手动输入 IP，格式如 192.168.1.x')),
    );
  }
}

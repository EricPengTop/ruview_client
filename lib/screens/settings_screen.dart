import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        _sectionHeader('服务器连接'),
        const SizedBox(height: 8),
        Card(
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
                    Text(
                      isConnected ? '已连接' : '未连接',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (isConnected && state.latestUpdate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '数据: ${state.latestUpdate!.classification.presence ? "有人" : "无人"}, ${state.latestUpdate!.vitalSigns.heartRateBpm.toStringAsFixed(0)}bpm',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: () {
                        if (isConnected) {
                          notifier.disconnect();
                        } else {
                          notifier.connect(
                            _hostController.text,
                            int.tryParse(_portController.text) ?? 3001,
                          );
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
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 16),
          _sectionHeader('服务器信息'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _infoTile('消息总数', '#${state.msgCount}'),
                if (state.latestUpdate != null) ...[
                  const Divider(height: 1),
                  _infoTile('服务端 Tick', 't=${state.latestUpdate!.tick}'),
                  const Divider(height: 1),
                  _infoTile(
                    '信号质量',
                    '${(state.latestUpdate!.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%',
                  ),
                  const Divider(height: 1),
                  _infoTile(
                    'RSSI',
                    '${state.latestUpdate!.features.meanRssi.toStringAsFixed(0)} dBm',
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _sectionHeader('告警日志'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('告警日志'),
                subtitle: Text(
                  '共 ${state.alerts.length} 条，未读 ${state.unreadAlertCount}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                value: true,
                onChanged: (_) => notifier.clearAlerts(),
                secondary: const Icon(Icons.notifications_off_outlined),
              ),
              if (state.alerts.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: FilledButton.tonal(
                    onPressed: () => notifier.clearAlerts(),
                    child: const Text('清空所有告警'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader('外观'),
        const SizedBox(height: 8),
        Card(
          child:           SwitchListTile(
            title: const Text('暗色模式'),
            subtitle: const Text('切换深色/浅色主题'),
            value: state.isDarkMode,
            onChanged: (_) => notifier.toggleTheme(),
            secondary: Icon(
              state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader('关于'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoTile('应用名', 'RuView 客户端'),
              const Divider(height: 1),
              _infoTile('版本', '1.0.0'),
              const Divider(height: 1),
              _infoTile('数据源', 'RuView WiFi Sensing Server'),
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
        ),
        const SizedBox(height: 32),
      ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
      ),
      dense: true,
    );
  }
}

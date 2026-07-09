import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../services/ws_service.dart';

/// 开发者调试页面 (WebSocket日志/连接管理/数据预览)
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final _scrollController = ScrollController();
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '3001');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;

    ref.listen(appStateProvider, (prev, next) {
      if (next.log.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final pos = _scrollController.position;
            if (pos.pixels >= pos.maxScrollExtent - 5) {
              _scrollController.jumpTo(pos.maxScrollExtent);
            }
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.getString('debug_title')),
            if (state.msgCount > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text('#${state.msgCount}', style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ],
          ],
        ),
        actions: [
          if (state.log.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: notifier.clearLog, tooltip: s.getString('debug_clear_log')),
          _buildConnectionChip(notifier, isConnected, s),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsBar(isConnected, s),
          const Divider(height: 1),
          if (state.latestUpdate != null) _buildVitalsStrip(state.latestUpdate!, s),
          Expanded(child: _buildLogView(state.log, s)),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(AppStateNotifier notifier, bool isConnected, AppStrings s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isConnected ? Icons.circle : Icons.circle_outlined, color: isConnected ? Colors.green : Colors.grey, size: 12),
        const SizedBox(width: 6),
        Text(isConnected ? s.getString('connected') : s.getString('not_connected'), style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: () {
            if (isConnected) {
              notifier.disconnect();
            } else {
              notifier.connect(_hostController.text, int.tryParse(_portController.text) ?? 3001);
            }
          },
          icon: Icon(isConnected ? Icons.stop : Icons.play_arrow, size: 18),
          label: Text(isConnected ? s.getString('disconnect') : s.getString('connect')),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        ),
      ],
    );
  }

  Widget _buildSettingsBar(bool isConnected, AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(flex: 2, child: TextField(controller: _hostController, enabled: !isConnected, decoration: InputDecoration(labelText: s.getString('srv_host'), border: const OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _portController, enabled: !isConnected, decoration: InputDecoration(labelText: s.getString('srv_port'), border: const OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
        ],
      ),
    );
  }

  Widget _buildVitalsStrip(SensingUpdate update, AppStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _vitalChip(s.getString('dash_presence_yes'), update.classification.presence ? s.getString('yes') : s.getString('no'), update.classification.presence ? Colors.green : Colors.red),
        _vitalChip(s.getString('dash_motion'), _motionLabel(update.classification.motionLevel, s), Colors.orange),
        _vitalChip(s.getString('vitals_hr'), '${update.vitalSigns.heartRateBpm.toStringAsFixed(0)} bpm', null),
        _vitalChip(s.getString('vitals_br'), '${update.vitalSigns.breathingRateBpm.toStringAsFixed(0)} bpm', null),
        _vitalChip(s.getString('dash_persons'), '${update.estimatedPersons}', null),
        _vitalChip(s.getString('dash_signal'), '${(update.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%', null),
      ]),
    );
  }

  String _motionLabel(String level, AppStrings s) {
    switch (level) {
      case 'present_still': return s.getString('dash_motion_still');
      case 'present_moving': return s.getString('dash_motion_moving');
      case 'absent': return s.getString('not_connected_msg');
      default: return level;
    }
  }

  Widget _vitalChip(String label, String value, Color? color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _buildLogView(List<String> log, AppStrings s) {
    if (log.isEmpty) return Center(child: Text(s.getString('debug_no_messages')));

    return ListView.builder(
      controller: _scrollController,
      itemCount: log.length,
      itemBuilder: (context, i) {
        final entry = log[i];
        final isError = entry.contains('错误:');
        final isConnected = entry.contains('连接状态: 已连接');
        Color? textColor;
        if (isError) {
          textColor = Colors.red.shade300;
        } else if (isConnected) {
          textColor = Colors.green.shade300;
        } else if (entry.contains('连接状态:')) {
          textColor = Colors.orange.shade300;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(entry, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textColor)),
        );
      },
    );
  }
}

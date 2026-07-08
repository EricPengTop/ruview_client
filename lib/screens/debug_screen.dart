import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';

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
    final isConnected = state.connectionState.isConnected;

    if (state.log.isNotEmpty && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('RuView 调试'),
            if (state.msgCount > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  '#${state.msgCount}',
                  style: const TextStyle(fontSize: 11),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ],
          ],
        ),
        actions: [
          if (state.log.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => notifier.clearLog(),
              tooltip: '清空日志',
            ),
          _buildConnectionChip(notifier, isConnected),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsBar(isConnected),
          const Divider(height: 1),
          if (state.latestUpdate != null)
            _buildVitalsStrip(state.latestUpdate!),
          Expanded(child: _buildLogView(state.log)),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(AppStateNotifier notifier, bool isConnected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConnected ? Icons.circle : Icons.circle_outlined,
          color: isConnected ? Colors.green : Colors.grey,
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(isConnected ? '已连接' : '未连接', style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
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
          icon: Icon(isConnected ? Icons.stop : Icons.play_arrow, size: 18),
          label: Text(isConnected ? '断开连接' : '连接'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsBar(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _hostController,
              enabled: !isConnected,
              decoration: const InputDecoration(
                labelText: '主机地址',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _portController,
              enabled: !isConnected,
              decoration: const InputDecoration(
                labelText: '端口',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsStrip(SensingUpdate update) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _vitalChip(
            '人体存在',
            update.classification.presence ? '是' : '否',
            update.classification.presence ? Colors.green : Colors.red,
          ),
          _vitalChip(
            '运动状态',
            _motionLabel(update.classification.motionLevel),
            Colors.orange,
          ),
          _vitalChip(
            '心率',
            '${update.vitalSigns.heartRateBpm.toStringAsFixed(0)} bpm',
            null,
          ),
          _vitalChip(
            '呼吸率',
            '${update.vitalSigns.breathingRateBpm.toStringAsFixed(0)} bpm',
            null,
          ),
          _vitalChip('人数', '${update.estimatedPersons}', null),
          _vitalChip(
            '信号质量',
            '${(update.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%',
            null,
          ),
        ],
      ),
    );
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

  Widget _vitalChip(String label, String value, Color? color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLogView(List<String> log) {
    if (log.isEmpty) {
      return const Center(child: Text('暂无消息，点击连接开始'));
    }

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
          child: Text(
            entry,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: textColor,
            ),
          ),
        );
      },
    );
  }
}

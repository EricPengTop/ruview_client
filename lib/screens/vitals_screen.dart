import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ws_service.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) {
      return const Center(child: Text('未连接'));
    }

    final history = state.vitalsHistory;
    if (history.isEmpty) {
      return const Center(child: Text('等待生命体征数据...'));
    }

    if (state.isPrivacyMode) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text('隐私模式已启用',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
            const SizedBox(height: 4),
            Text('心率/呼吸率数据已隐藏',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final paused = state.isPaused;
    final selectedIndex = state.pausedIndex.clamp(0, history.length - 1);
    final selectedRecord = history[selectedIndex];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildControlBar(notifier, paused, history.length, selectedRecord, context, history),
          const SizedBox(height: 8),
          _buildSlider(notifier, paused, history.length, selectedIndex),
          const SizedBox(height: 8),
          Expanded(
            child: _buildChart('心率', Colors.red, history, paused, selectedIndex),
          ),
          const Divider(),
          Expanded(
            child: _buildChart('呼吸率', Colors.blue, history, paused, selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(
    AppStateNotifier notifier,
    bool paused,
    int frameCount,
    VitalsRecord record,
    BuildContext context,
    List<VitalsRecord> history,
  ) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: () => notifier.togglePause(),
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          iconSize: 18,
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            backgroundColor: paused
                ? Colors.orange.withValues(alpha: 0.2)
                : null,
          ),
          tooltip: paused ? '继续' : '暂停',
        ),
        const SizedBox(width: 8),
        Text(
          paused ? '暂停中' : '实时',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: paused ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '共 $frameCount 帧',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const Spacer(),
        _buildLatestValue('心率', Colors.red, record),
        const SizedBox(width: 12),
        _buildLatestValue('呼吸率', Colors.blue, record),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download, size: 18),
          tooltip: '导出 CSV',
          onPressed: () => _exportCsv(context, history),
        ),
        IconButton(
          icon: const Icon(Icons.assessment, size: 18),
          tooltip: '健康报告',
          onPressed: () => _showReport(context, history),
        ),
      ],
    );
  }

  Widget _buildSlider(
    AppStateNotifier notifier,
    bool paused,
    int frameCount,
    int selectedIndex,
  ) {
    return Row(
      children: [
        Text(
          '#${selectedIndex + 1}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: selectedIndex.toDouble(),
              min: 0,
              max: (frameCount - 1).toDouble(),
              divisions: frameCount > 1 ? frameCount - 1 : 1,
              onChanged: paused
                  ? (v) => notifier.seekToFrame(v.toInt())
                  : null,
              activeColor: paused ? Colors.orange : Colors.grey,
              inactiveColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ),
        Text(
          '#$frameCount',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildChart(
    String title,
    Color color,
    List<VitalsRecord> history,
    bool paused,
    int selectedIndex,
  ) {
    final isHr = title == '心率';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: isHr ? 0 : 0,
              maxY: isHr ? 120 : 30,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: isHr ? 20 : 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade800,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: isHr ? 20 : 5,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  axisNameWidget: Text('', style: TextStyle(fontSize: 1)),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: history
                      .asMap()
                      .entries
                      .map((e) => FlSpot(
                            e.key.toDouble(),
                            isHr ? e.value.heartRate : e.value.breathingRate,
                          ))
                      .toList(),
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: paused,
                    getDotPainter: (spot, a, b, c) => FlDotCirclePainter(
                      radius: spot.x.toInt() == selectedIndex ? 4 : 0,
                      color: color,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestValue(
      String title, Color color, VitalsRecord record) {
    final value =
        title == '心率' ? record.heartRate : record.breathingRate;
    final conf =
        title == '心率' ? record.hrConfidence : record.brConfidence;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(conf * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

void _showReport(BuildContext context, List<VitalsRecord> history) {
  if (history.isEmpty) return;
  final hrVals = history.map((r) => r.heartRate).toList();
  final brVals = history.map((r) => r.breathingRate).toList();
  final avgHr = hrVals.reduce((a, b) => a + b) / hrVals.length;
  final avgBr = brVals.reduce((a, b) => a + b) / brVals.length;
  hrVals.sort();
  brVals.sort();
  final minHr = hrVals.first;
  final maxHr = hrVals.last;
  final minBr = brVals.first;
  final maxBr = brVals.last;
  final sigAvg = history.map((r) => r.signalQuality).reduce((a, b) => a + b) / history.length;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('健康报告'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('样本: ${history.length} 帧'),
          const Divider(),
          Text('心率: 平均 ${avgHr.toStringAsFixed(1)} bpm'),
          Text('　　   最低 ${minHr.toStringAsFixed(1)} / 最高 ${maxHr.toStringAsFixed(1)}'),
          const Divider(),
          Text('呼吸: 平均 ${avgBr.toStringAsFixed(1)} bpm'),
          Text('　　   最低 ${minBr.toStringAsFixed(1)} / 最高 ${maxBr.toStringAsFixed(1)}'),
          const Divider(),
          Text('信号质量均值: ${(sigAvg * 100).toStringAsFixed(0)}%'),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    ),
  );
}

Future<void> _exportCsv(BuildContext context, List<VitalsRecord> history) async {
  final ts = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-')
      .substring(0, 19);
  final home = Platform.environment['HOME'] ?? '.';
  final path = '$home/Downloads/ruview_导出_$ts.csv';

  final buf = StringBuffer()
    ..writeln('时间,心率(bpm),心率可信度,呼吸率(bpm),呼吸率可信度');
  for (final r in history) {
    buf.writeln(
      '${r.time.toIso8601String()},${r.heartRate},${r.hrConfidence},${r.breathingRate},${r.brConfidence}',
    );
  }

  try {
    await File(path).writeAsString(buf.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出 ${history.length} 条记录 → $path'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
}

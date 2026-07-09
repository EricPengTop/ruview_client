import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../services/ws_service.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) {
      return Center(child: Text(s.getString('not_connected_msg')));
    }

    final history = state.vitalsHistory;
    if (history.isEmpty) {
      return Center(child: Text(s.getString('vitals_wait')));
    }

    if (state.isPrivacyMode) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              s.getString('privacy_enabled'),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 4),
            Text(
              s.getString('privacy_hidden'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
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
          _buildControlBar(
            notifier,
            paused,
            history.length,
            selectedRecord,
            context,
            history,
            s,
          ),
          const SizedBox(height: 8),
          _buildSlider(notifier, paused, history.length, selectedIndex),
          const SizedBox(height: 8),
          Expanded(
            child: _buildChart(
              s.getString('vitals_hr'),
              Colors.red,
              history,
              paused,
              selectedIndex,
              s,
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildChart(
              s.getString('vitals_br'),
              Colors.blue,
              history,
              paused,
              selectedIndex,
              s,
            ),
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
    AppStrings s,
  ) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: notifier.togglePause,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          iconSize: 18,
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            backgroundColor: paused
                ? Colors.orange.withValues(alpha: 0.2)
                : null,
          ),
          tooltip: paused
              ? s.getString('vitals_resume')
              : s.getString('vitals_pause'),
        ),
        const SizedBox(width: 8),
        Text(
          paused ? s.getString('vitals_paused') : s.getString('vitals_live'),
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
            s.format('vitals_frames', args: {'count': '$frameCount'}),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const Spacer(),
        _buildLatestValue(s.getString('vitals_hr'), Colors.red, record, s),
        const SizedBox(width: 12),
        _buildLatestValue(s.getString('vitals_br'), Colors.blue, record, s),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download, size: 18),
          tooltip: s.getString('vitals_export'),
          onPressed: () => _exportCsv(context, history, s),
        ),
        IconButton(
          icon: const Icon(Icons.assessment, size: 18),
          tooltip: s.getString('vitals_report'),
          onPressed: () => _showReport(context, history, s),
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
              onChanged: paused ? (v) => notifier.seekToFrame(v.toInt()) : null,
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
    AppStrings s,
  ) {
    final isHr = title == s.getString('vitals_hr');
    return Expanded(
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: isHr ? 120 : 30,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: isHr ? 20 : 5,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: isHr ? 20 : 5,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              axisNameWidget: Text('', style: TextStyle(fontSize: 1)),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: history
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      isHr ? e.value.heartRate : e.value.breathingRate,
                    ),
                  )
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
    );
  }

  Widget _buildLatestValue(
    String title,
    Color color,
    VitalsRecord record,
    AppStrings s,
  ) {
    final isHr = title == s.getString('vitals_hr');
    final value = isHr ? record.heartRate : record.breathingRate;
    final conf = isHr ? record.hrConfidence : record.brConfidence;
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

void _showReport(
  BuildContext context,
  List<VitalsRecord> history,
  AppStrings s,
) {
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
  final sigAvg =
      history.map((r) => r.signalQuality).reduce((a, b) => a + b) /
      history.length;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(s.getString('vitals_report_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.format(
              'vitals_report_samples',
              args: {'count': '${history.length}'},
            ),
          ),
          const Divider(),
          Text(
            s.format(
              'vitals_report_hr_avg',
              args: {'avg': avgHr.toStringAsFixed(1)},
            ),
          ),
          Text(
            s.format(
              'vitals_report_hr_range',
              args: {
                'min': minHr.toStringAsFixed(1),
                'max': maxHr.toStringAsFixed(1),
              },
            ),
          ),
          const Divider(),
          Text(
            s.format(
              'vitals_report_br_avg',
              args: {'avg': avgBr.toStringAsFixed(1)},
            ),
          ),
          Text(
            s.format(
              'vitals_report_br_range',
              args: {
                'min': minBr.toStringAsFixed(1),
                'max': maxBr.toStringAsFixed(1),
              },
            ),
          ),
          const Divider(),
          Text(
            s.format(
              'vitals_report_sig',
              args: {'val': (sigAvg * 100).toStringAsFixed(0)},
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.getString('vitals_close')),
        ),
      ],
    ),
  );
}

Future<void> _exportCsv(
  BuildContext context,
  List<VitalsRecord> history,
  AppStrings s,
) async {
  final ts = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-')
      .substring(0, 19);
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final dir = Directory('$home/Downloads');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final path = '${dir.path}/ruview_$ts.csv';
  final buf = StringBuffer()..writeln(s.getString('vitals_csv_header'));
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
          content: Text(
            s.format(
              'vitals_export_success',
              args: {'count': '${history.length}', 'path': path},
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.format('vitals_export_fail', args: {'error': e.toString()}),
          ),
        ),
      );
    }
  }
}

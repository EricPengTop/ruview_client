import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ws_service.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) {
      return const Center(child: Text('未连接'));
    }

    if (state.vitalsHistory.isEmpty) {
      return const Center(child: Text('等待生命体征数据...'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(child: _buildChart('心率', Colors.red, state.vitalsHistory)),
          const Divider(),
          Expanded(
              child: _buildChart('呼吸率', Colors.blue, state.vitalsHistory)),
        ],
      ),
    );
  }

  Widget _buildChart(
      String title, Color color, List<VitalsRecord> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
            const Spacer(),
            if (history.isNotEmpty) _buildLatestValue(title, color, history.last),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: title == '心率' ? 0 : 0,
              maxY: title == '心率' ? 120 : 30,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: title == '心率' ? 20 : 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade800,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: title == '心率' ? 20 : 5,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  axisNameWidget: Text('', style: TextStyle(fontSize: 1)),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                            title == '心率'
                                ? e.value.heartRate
                                : e.value.breathingRate,
                          ))
                      .toList(),
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
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
    final value = title == '心率' ? record.heartRate : record.breathingRate;
    final conf = title == '心率' ? record.hrConfidence : record.brConfidence;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value.toStringAsFixed(1)} bpm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${(conf * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ),
      ],
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../services/ws_service.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) {
      return Center(child: Text(s.getString('not_connected_msg')));
    }

    final u = state.latestUpdate;
    if (u == null) return Center(child: Text(s.getString('not_connected_msg')));

    final securityAlerts = state.alerts.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(u, s),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildRecentAlerts(securityAlerts, s)),
                const SizedBox(width: 12),
                Expanded(child: _buildActionsPanel(s)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: _buildSignalChart(state.vitalsHistory, s),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(SensingUpdate update, AppStrings s) {
    final presence = update.classification.presence;
    final signalQ = update.vitalSigns.signalQuality;
    return Card(
      color: presence
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              presence ? Icons.security : Icons.security_outlined,
              size: 32,
              color: presence ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presence
                      ? s.getString('sec_status_ok')
                      : s.getString('sec_status_monitor'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: presence ? Colors.green : Colors.grey,
                  ),
                ),
                Text(
                  '${s.getString("sec_signal_info")}: ${(signalQ * 100).toStringAsFixed(0)}% | ${s.getString("dash_persons")}: ${update.estimatedPersons}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
            const Spacer(),
            _buildThreatIndicator(update, s),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatIndicator(SensingUpdate update, AppStrings s) {
    final signalQ = update.vitalSigns.signalQuality;
    final level = signalQ < 0.3
        ? s.getString('sec_detail_low')
        : signalQ < 0.5
        ? s.getString('sec_detail_mid')
        : s.getString('sec_detail_high');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: signalQ < 0.3
            ? Colors.red.withValues(alpha: 0.2)
            : signalQ < 0.5
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s.format('sec_detail_label', args: {'level': level}),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildRecentAlerts(List<Alert> alerts, AppStrings s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 4),
                Text(
                  s.getString('sec_log'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Text(
                        s.getString('sec_log_empty'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: alerts.length > 15 ? 15 : alerts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final a = alerts[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _eventColor(a.type),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${s.getString(a.type.labelKey)}${a.details.isNotEmpty ? " (${a.details})" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${a.time.hour.toString().padLeft(2, '0')}:${a.time.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsPanel(AppStrings s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, size: 16),
                const SizedBox(width: 4),
                Text(
                  s.getString('sec_actions'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _actionButton(
              Icons.notifications_active,
              s.getString('sec_action_emergency'),
              Colors.red,
            ),
            const SizedBox(height: 8),
            _actionButton(
              Icons.lock,
              s.getString('sec_action_lockdown'),
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _actionButton(
              Icons.record_voice_over,
              s.getString('sec_action_voice'),
              Colors.amber,
            ),
            const SizedBox(height: 8),
            _actionButton(
              Icons.phone,
              s.getString('sec_action_contact'),
              Colors.blue,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 16),
              label: Text(s.getString('sec_action_export')),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Color _eventColor(AlertType type) {
    switch (type) {
      case AlertType.presenceAppeared:
        return Colors.green;
      case AlertType.presenceDisappeared:
        return Colors.grey;
      case AlertType.motionStarted:
      case AlertType.motionStopped:
        return Colors.orange;
      case AlertType.personCountChanged:
        return Colors.cyan;
      case AlertType.signalLow:
      case AlertType.hrHigh:
      case AlertType.brLow:
        return Colors.red;
      case AlertType.hrLow:
      case AlertType.brHigh:
        return Colors.purple;
    }
  }

  Widget _buildSignalChart(List<VitalsRecord> history, AppStrings s) {
    if (history.length < 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        child: Row(
          children: [
            RotatedBox(
              quarterTurns: -1,
              child: Text(
                s.getString('sec_signal_chart'),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 0.25,
                        getTitlesWidget: _signalYTitles,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
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
                            (e) =>
                                FlSpot(e.key.toDouble(), e.value.signalQuality),
                          )
                          .toList(),
                      isCurved: true,
                      color: Colors.amber,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.amber.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _signalYTitles(double v, TitleMeta meta) {
    return Text(
      '${(v * 100).toInt()}%',
      style: const TextStyle(fontSize: 9, color: Colors.grey),
    );
  }
}

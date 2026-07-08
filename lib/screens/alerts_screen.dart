import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../services/ws_service.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) return Center(child: Text(s.getString('not_connected_msg')));

    final alerts = state.alerts.reversed.toList();
    if (alerts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(s.getString('alerts_empty'), style: TextStyle(color: Colors.grey.shade400)),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Text(s.format('alerts_total', args: {'count': '${alerts.length}'}), style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            const Spacer(),
            TextButton(onPressed: notifier.clearAlerts, child: Text(s.getString('alert_clear'))),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: alerts.length, separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final alert = alerts[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(radius: 16, backgroundColor: _alertColor(alert.type).withValues(alpha: 0.15), child: Icon(_alertIcon(alert.type), size: 16, color: _alertColor(alert.type))),
                  title: Text(s.getString(alert.type.labelKey), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.getString(alert.type.descKey), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${alert.time.hour.toString().padLeft(2, '0')}:${alert.time.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    if (alert.details.isNotEmpty) Text(alert.details, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _alertColor(AlertType type) {
    switch (type) {
      case AlertType.presenceAppeared: case AlertType.motionStarted: return Colors.orange;
      case AlertType.presenceDisappeared: return Colors.grey;
      case AlertType.motionStopped: return Colors.blue;
      case AlertType.personCountChanged: return Colors.cyan;
      case AlertType.signalLow: case AlertType.hrHigh: case AlertType.brLow: return Colors.red;
      case AlertType.hrLow: case AlertType.brHigh: return Colors.purple;
    }
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.presenceAppeared: return Icons.person_add;
      case AlertType.presenceDisappeared: return Icons.person_off;
      case AlertType.motionStarted: return Icons.directions_run;
      case AlertType.motionStopped: return Icons.airline_seat_flat;
      case AlertType.personCountChanged: return Icons.people;
      case AlertType.signalLow: return Icons.signal_cellular_alt;
      case AlertType.hrHigh: case AlertType.hrLow: case AlertType.brHigh: case AlertType.brLow: return Icons.monitor_heart;
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';
import '../l10n/app_locale.dart';
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
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.getString('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(s.getString('srv_connection')),
          _buildServerCard(notifier, isConnected, state, s),
          if (isConnected) ...[
            _section(s.getString('srv_info')),
            _buildServerInfo(state, s),
          ],
          _section(s.getString('alert_log')),
          _buildAlertsCard(notifier, state, s, context),
          _section(s.getString('alert_rules')),
          _buildAlertRules(notifier, state, s),
          _section(s.getString('privacy')),
          _buildPrivacyCard(notifier, state, s),
          _section(s.getString('appearance')),
          _buildThemeCard(notifier, state, s),
          _section(s.getString('language')),
          _buildLanguageCard(notifier, state, s),
          _section(s.getString('about')),
          _buildAboutCard(context, s),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
      ),
    ),
  );

  Widget _infoRow(String label, String value) => ListTile(
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: Text(
      value,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
    ),
    dense: true,
  );

  Widget _buildServerCard(
    AppStateNotifier n,
    bool conn,
    AppState st,
    AppStrings s,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: conn ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  conn
                      ? s.getString('connected')
                      : s.getString('not_connected'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (conn && st.latestUpdate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${s.getString('srv_data_preview')}: ${st.latestUpdate!.classification.presence ? s.getString("yes") : s.getString("no")}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => conn
                      ? n.disconnect()
                      : n.connect(
                          _hostController.text,
                          int.tryParse(_portController.text) ?? 3001,
                        ),
                  child: Text(
                    conn ? s.getString('disconnect') : s.getString('connect'),
                  ),
                ),
              ],
            ),
            if (!conn) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: s.getString('srv_host'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: s.getString('srv_port'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanLocalhost(context, s),
                      icon: const Icon(Icons.dns, size: 16),
                      label: Text(s.getString('srv_scan_local')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanNetwork(context, s),
                      icon: const Icon(Icons.wifi_find, size: 16),
                      label: Text(s.getString('srv_scan_net')),
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

  Widget _buildServerInfo(AppState st, AppStrings s) {
    return Card(
      child: Column(
        children: [
          _infoRow(s.getString('srv_msg_count'), '#${st.msgCount}'),
          if (st.latestUpdate != null) ...[
            const Divider(height: 1),
            _infoRow(s.getString('srv_tick'), 't=${st.latestUpdate!.tick}'),
            const Divider(height: 1),
            _infoRow(
              s.getString('srv_signal'),
              '${(st.latestUpdate!.vitalSigns.signalQuality * 100).toStringAsFixed(0)}%',
            ),
            const Divider(height: 1),
            _infoRow(
              s.getString('srv_rssi'),
              '${st.latestUpdate!.features.meanRssi.toStringAsFixed(0)} dBm',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsCard(
    AppStateNotifier n,
    AppState st,
    AppStrings s,
    BuildContext context,
  ) {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => _showAlertDetail(context, st, s),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Badge(
                    isLabelVisible: st.unreadAlertCount > 0,
                    label: Text(st.unreadAlertCount.toString()),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.getString('alert_log'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.format(
                            'alert_total',
                            args: {'count': '${st.alerts.length}'},
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
          if (st.alerts.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: n.markAlertsRead,
                    child: Text(s.getString('alert_mark_read')),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: n.clearAlerts,
                    child: Text(s.getString('alert_clear')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertRules(AppStateNotifier n, AppState st, AppStrings s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sliderRow(
              s.getString('alert_hr_high'),
              st.hrMax,
              0,
              200,
              n.setHrMax,
              'bpm',
            ),
            _sliderRow(
              s.getString('alert_hr_low'),
              st.hrMin,
              0,
              200,
              n.setHrMin,
              'bpm',
            ),
            const Divider(height: 20),
            _sliderRow(
              s.getString('alert_br_high'),
              st.brMax,
              0,
              50,
              n.setBrMax,
              'bpm',
            ),
            _sliderRow(
              s.getString('alert_br_low'),
              st.brMin,
              0,
              50,
              n.setBrMin,
              'bpm',
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              label: '${value.toStringAsFixed(0)} $unit',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.toStringAsFixed(0)} $unit',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(AppStateNotifier n, AppState st, AppStrings s) {
    return Card(
      child: SwitchListTile(
        title: Text(s.getString('privacy_mode')),
        subtitle: Text(s.getString('privacy_desc')),
        value: st.isPrivacyMode,
        onChanged: (_) => n.togglePrivacyMode(),
        secondary: Icon(
          st.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildThemeCard(AppStateNotifier n, AppState st, AppStrings s) {
    return Card(
      child: SwitchListTile(
        title: Text(s.getString('dark_mode')),
        subtitle: Text(s.getString('dark_mode_desc')),
        value: st.isDarkMode,
        onChanged: (_) => n.toggleTheme(),
        secondary: Icon(
          st.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildLanguageCard(AppStateNotifier n, AppState st, AppStrings s) {
    return Card(
      child: SwitchListTile(
        title: Text(s.getString('lang_label')),
        subtitle: Text(
          st.locale == 'zh'
              ? s.getString('lang_current_zh')
              : s.getString('lang_current_en'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
        value: st.locale == 'en',
        onChanged: (_) => n.toggleLocale(),
        secondary: const Icon(Icons.language, color: Colors.grey),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, AppStrings s) {
    return Card(
      child: Column(
        children: [
          _infoRow(s.getString('about_name'), s.getString('about_value')),
          const Divider(height: 1),
          _infoRow(s.getString('about_version'), '1.0.0'),
          const Divider(height: 1),
          _infoRow(s.getString('about_source'), 'RuView WiFi Sensing Server'),
          const Divider(height: 1),
          ListTile(
            title: Text(
              s.getString('dev_tools'),
              style: const TextStyle(fontSize: 14),
            ),
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
      case AlertType.hrHigh:
      case AlertType.hrLow:
      case AlertType.brHigh:
      case AlertType.brLow:
        return Icons.monitor_heart;
    }
  }

  void _showAlertDetail(BuildContext context, AppState st, AppStrings s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(s.getString('alert_log'))),
          body: ListView.builder(
            itemCount: st.alerts.reversed.length,
            itemBuilder: (ctx, i) {
              final a = st.alerts.reversed.toList()[i];
              final bg = a.type == AlertType.presenceAppeared
                  ? Colors.green.withValues(alpha: 0.2)
                  : a.type == AlertType.presenceDisappeared
                  ? Colors.grey.withValues(alpha: 0.2)
                  : a.type == AlertType.signalLow ||
                        a.type == AlertType.hrHigh ||
                        a.type == AlertType.brLow
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2);
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: bg,
                  child: Icon(_alertIcon(a.type), size: 14),
                ),
                title: Text(
                  s.getString(a.type.labelKey),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  s.getString(a.type.descKey),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                trailing: Text(
                  '${a.time.hour.toString().padLeft(2, '0')}:${a.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _scanLocalhost(BuildContext context, AppStrings s) async {
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
        SnackBar(content: Text(s.getString('srv_scan_no_result'))),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(s.getString('srv_scan_found')),
          content: Text(
            '${s.getString('srv_scan_ports')}: ${found.join(', ')}',
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
  }
}

Future<void> _scanNetwork(BuildContext context, AppStrings s) async {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.getString('srv_scan_manual'))));
  }
}

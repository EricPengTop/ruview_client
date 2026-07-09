import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../services/ws_service.dart';
import 'dashboard_screen.dart';
import 'vitals_screen.dart';
import 'pose_screen.dart';
import 'zones_screen.dart';
import 'alerts_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';

/// 主页面 (6 Tab 导航 + 连接管理 + 自动连接)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider.notifier).autoConnect();
    });
  }

  final _screens = const [
    DashboardScreen(),
    VitalsScreen(),
    PoseScreen(),
    ZonesScreen(),
    AlertsScreen(),
    SecurityScreen(),
  ];

  final _titles = [
    (AppStrings s) => s.getString('tab_overview_full'),
    (AppStrings s) => s.getString('tab_overview'),
    (AppStrings s) => s.getString('tab_pose'),
    (AppStrings s) => s.getString('tab_zones'),
    (AppStrings s) => s.getString('tab_alerts'),
    (AppStrings s) => s.getString('tab_security_full'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isConnected = state.connectionState.isConnected;
    final unread = state.unreadAlertCount;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex](s)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: s.getString('settings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _buildConnectionChip(notifier, isConnected, s),
          const SizedBox(width: 12),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          notifier.setTabIndex(i);
          if (i == 4) notifier.markAlertsRead();
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: s.getString('tab_overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outlined),
            selectedIcon: const Icon(Icons.favorite),
            label: s.getString('tab_vitals'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.accessibility_new_outlined),
            selectedIcon: const Icon(Icons.accessibility_new),
            label: s.getString('tab_pose'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: s.getString('tab_zones'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread.toString()),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread.toString()),
              child: const Icon(Icons.notifications),
            ),
            label: s.getString('tab_alerts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.security_outlined),
            selectedIcon: const Icon(Icons.security),
            label: s.getString('tab_security'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(
    AppStateNotifier notifier,
    bool isConnected,
    AppStrings s,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConnected ? Icons.circle : Icons.circle_outlined,
          color: isConnected ? Colors.green : Colors.grey,
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? s.getString('connected') : s.getString('not_connected'),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: () {
            if (isConnected) {
              notifier.disconnect();
            } else {
              showDialog(
                context: context,
                builder: (_) => _ConnectDialog(notifier: notifier, s: s),
              );
            }
          },
          icon: Icon(isConnected ? Icons.stop : Icons.play_arrow, size: 18),
          label: Text(
            isConnected ? s.getString('disconnect') : s.getString('connect'),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ],
    );
  }
}

class _ConnectDialog extends StatefulWidget {
  final AppStateNotifier notifier;
  final AppStrings s;

  const _ConnectDialog({required this.notifier, required this.s});

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final _host = TextEditingController(text: 'localhost');
  final _port = TextEditingController(text: '3001');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.s.getString('connect_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _host,
            decoration: InputDecoration(
              labelText: widget.s.getString('srv_host'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            decoration: InputDecoration(
              labelText: widget.s.getString('srv_port'),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.s.getString('connect_cancel')),
        ),
        FilledButton(
          onPressed: () {
            widget.notifier.connect(
              _host.text,
              int.tryParse(_port.text) ?? 3001,
            );
            Navigator.pop(context);
          },
          child: Text(widget.s.getString('connect')),
        ),
      ],
    );
  }
}

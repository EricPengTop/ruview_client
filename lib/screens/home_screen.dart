import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ws_service.dart';
import 'dashboard_screen.dart';
import 'vitals_screen.dart';
import 'pose_screen.dart';
import 'zones_screen.dart';
import 'debug_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    VitalsScreen(),
    PoseScreen(),
    ZonesScreen(),
  ];

  final _titles = const ['概览', '生命体征', '人体姿态', '区域监控'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isConnected = state.connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, size: 20),
            tooltip: '调试',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugScreen()),
            ),
          ),
          _buildConnectionChip(notifier, isConnected),
          const SizedBox(width: 12),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '概览',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '生命体征',
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new_outlined),
            selectedIcon: Icon(Icons.accessibility_new),
            label: '姿态',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '区域',
          ),
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
        Text(
          isConnected ? '已连接' : '未连接',
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
                builder: (_) => _ConnectDialog(notifier: notifier),
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
}

class _ConnectDialog extends StatefulWidget {
  final AppStateNotifier notifier;
  const _ConnectDialog({required this.notifier});

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
      title: const Text('连接 RuView 服务'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: '主机地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            decoration: const InputDecoration(
              labelText: '端口',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.notifier.connect(
              _host.text,
              int.tryParse(_port.text) ?? 3001,
            );
            Navigator.pop(context);
          },
          child: const Text('连接'),
        ),
      ],
    );
  }
}

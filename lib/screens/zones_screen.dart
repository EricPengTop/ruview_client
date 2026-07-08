import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';
import 'zone_editor_screen.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) {
      return const Center(child: Text('未连接'));
    }

    final u = state.latestUpdate;
    if (u == null) {
      return const Center(child: Text('等待区域数据...'));
    }

    final personCount = u.estimatedPersons;
    final hasPeople = personCount > 0;
    final zones = state.customZones;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '区域概览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade300,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ZoneEditorScreen()),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('编辑区域'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (zones.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text('暂无自定义区域',
                        style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(height: 4),
                    Text('点击"编辑区域"开始划定',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                itemCount: zones.length,
                itemBuilder: (context, i) {
                  final zone = zones[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            hasPeople ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.map,
                          size: 18,
                          color: hasPeople ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(zone.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('${zone.points.length} 个顶点',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPeople)
                            Text('$personCount 人',
                                style: const TextStyle(fontSize: 13, color: Colors.green)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => notifier.removeZone(zone.id),
                            color: Colors.red.shade300,
                          ),
                        ],
                      ),
                      onTap: () => _showZoneDetail(context, zone),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(context, u),
        ],
      ),
    );
  }

  void _showZoneDetail(BuildContext context, CustomZone zone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(zone.name),
        content: Text('顶点数: ${zone.points.length}\n点按查看详情'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, SensingUpdate update) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildInfoItem(
                '检测人数', '${update.estimatedPersons} 人', Icons.people),
            const Divider(height: 16),
            _buildInfoItem(
              '信号场强度',
              update.features.motionBandPower.toStringAsFixed(2),
              Icons.sensors,
            ),
            const Divider(height: 16),
            _buildInfoItem(
              '环境变化点',
              '${update.features.changePoints}',
              Icons.timeline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

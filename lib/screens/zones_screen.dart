import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '区域概览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _ZoneCard(
                    label: '监控区域',
                    icon: Icons.home,
                    occupied: hasPeople,
                    personCount: personCount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: _ZoneCard(
                          label: '周边区域',
                          icon: Icons.yard,
                          occupied: false,
                          personCount: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _ZoneCard(
                          label: '入口',
                          icon: Icons.door_front_door,
                          occupied: hasPeople,
                          personCount: personCount,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(context, u),
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

class _ZoneCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool occupied;
  final int personCount;

  const _ZoneCard({
    required this.label,
    required this.icon,
    required this.occupied,
    required this.personCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      decoration: BoxDecoration(
        color: occupied
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: occupied
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: occupied ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            occupied ? '$personCount 人' : '空',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: occupied ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

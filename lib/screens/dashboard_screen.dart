import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/ws_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final u = state.latestUpdate;
    final isConnected = state.connectionState.isConnected;

    if (!isConnected || u == null) {
      return const Center(child: Text('未连接，请在右上角点"连接"'));
    }

    final presence = u.classification.presence;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPresenceBanner(context, presence),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _MetricCard(
                  icon: Icons.people,
                  label: '人数',
                  value: u.estimatedPersons.toString(),
                  unit: '人',
                  color: presence ? Colors.green : Colors.grey,
                ),
                _MetricCard(
                  icon: u.classification.motionLevel == 'present_still'
                      ? Icons.airline_seat_flat
                      : Icons.directions_run,
                  label: '运动状态',
                  value: u.classification.motionLevel == 'present_still'
                      ? '静止'
                      : u.classification.motionLevel == 'present_moving'
                          ? '运动中'
                          : u.classification.motionLevel,
                  unit: '',
                  color: theme.colorScheme.primary,
                ),
                _MetricCard(
                  icon: Icons.signal_cellular_alt,
                  label: '信号质量',
                  value: (u.vitalSigns.signalQuality * 100).toStringAsFixed(0),
                  unit: '%',
                  color: theme.colorScheme.tertiary,
                ),
                _MetricCard(
                  icon: Icons.wifi,
                  label: 'RSSI',
                  value: u.features.meanRssi.toStringAsFixed(0),
                  unit: 'dBm',
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPersonsList(u),
        ],
      ),
    );
  }

  Widget _buildPresenceBanner(BuildContext context, bool presence) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: presence
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presence
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            presence ? Icons.person : Icons.person_off,
            size: 48,
            color: presence ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 8),
          Text(
            presence ? '检测到人体存在' : '未检测到人体',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: presence ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonsList(SensingUpdate update) {
    if (update.persons.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识别目标 (共${update.persons.length}个)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: update.persons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = update.persons[i];
                return Chip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: Text(
                    '目标${p.trackId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: p.confidence > 0.7
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  side: BorderSide.none,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

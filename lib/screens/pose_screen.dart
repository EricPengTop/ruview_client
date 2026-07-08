import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../services/ws_service.dart';

class PoseScreen extends ConsumerWidget {
  const PoseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;

    if (!isConnected) return Center(child: Text(s.getString('not_connected_msg')));

    final persons = state.latestUpdate?.persons ?? [];
    if (persons.isEmpty) return Center(child: Text(s.getString('pose_wait')));

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: persons.length, separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = persons[i];
              return ChoiceChip(
                label: Text('${s.getString("pose_target")}${p.trackId} (${(p.confidence * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
                selected: true, onSelected: (_) => _showDetail(context, p, s), visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        Expanded(
          child: InteractiveViewer(minScale: 0.5, maxScale: 3.0,
            child: Center(child: CustomPaint(size: const Size(400, 500), painter: _SkeletonPainter(persons: persons))),
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, PoseDetection person, AppStrings s) {
    showModalBottomSheet(context: context, builder: (_) => _PoseDetailSheet(person: person, s: s));
  }
}

class _PoseDetailSheet extends StatelessWidget {
  final PoseDetection person;
  final AppStrings s;
  const _PoseDetailSheet({required this.person, required this.s});

  List<String> get _keypointNames => [
    s.getString('pose_kp_nose'), s.getString('pose_kp_left_eye'), s.getString('pose_kp_right_eye'),
    s.getString('pose_kp_left_ear'), s.getString('pose_kp_right_ear'),
    s.getString('pose_kp_left_shoulder'), s.getString('pose_kp_right_shoulder'),
    s.getString('pose_kp_left_elbow'), s.getString('pose_kp_right_elbow'),
    s.getString('pose_kp_left_wrist'), s.getString('pose_kp_right_wrist'),
    s.getString('pose_kp_left_hip'), s.getString('pose_kp_right_hip'),
    s.getString('pose_kp_left_knee'), s.getString('pose_kp_right_knee'),
    s.getString('pose_kp_left_ankle'), s.getString('pose_kp_right_ankle'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.person, size: 20), const SizedBox(width: 8),
          Text(s.format('pose_detail_title', args: {'id': '${person.trackId}'}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Chip(label: Text('${(person.confidence * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11)), backgroundColor: Colors.green.withValues(alpha: 0.15), side: BorderSide.none, visualDensity: VisualDensity.compact),
        ]),
        const Divider(),
        Flexible(
          child: ListView.builder(shrinkWrap: true, itemCount: person.keypoints.length, itemBuilder: (context, i) {
            final kp = person.keypoints[i];
            final name = i < _keypointNames.length ? _keypointNames[i] : '#$i';
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              SizedBox(width: 36, child: Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade400))),
              Expanded(child: Text('x: ${kp.x.toStringAsFixed(0)}  y: ${kp.y.toStringAsFixed(0)}  z: ${kp.z.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
              Text('${(kp.confidence * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: kp.confidence > 0.5 ? Colors.green : Colors.grey)),
            ]));
          }),
        ),
      ]),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final List<PoseDetection> persons;
  _SkeletonPainter({required this.persons});

  final _bonePaint = Paint()..color = Colors.cyan.withValues(alpha: 0.6)..strokeWidth = 2..style = PaintingStyle.stroke;
  final _jointPaint = Paint()..color = Colors.cyan..style = PaintingStyle.fill;

  static const _bones = [[0, 1], [0, 2], [1, 3], [2, 4], [5, 7], [7, 9], [6, 8], [8, 10], [5, 6], [5, 11], [6, 12], [11, 13], [13, 15], [12, 14], [14, 16], [11, 12]];

  @override
  void paint(Canvas canvas, Size size) {
    for (final person in persons) {
      if (person.keypoints.length < 17) continue;
      _drawSkeleton(canvas, size, person);
    }
  }

  void _drawSkeleton(Canvas canvas, Size size, PoseDetection person) {
    final joints = person.keypoints.map((k) => Offset(k.x / 640 * size.width, k.y / 480 * size.height)).toList();
    for (final bone in _bones) { canvas.drawLine(joints[bone[0]], joints[bone[1]], _bonePaint); }
    for (final j in joints) { canvas.drawCircle(j, 4, _jointPaint); }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) => old.persons != persons;
}

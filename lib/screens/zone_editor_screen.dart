import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../models/models.dart';
import '../services/ws_service.dart';

class ZoneEditorScreen extends ConsumerStatefulWidget {
  const ZoneEditorScreen({super.key});

  @override
  ConsumerState<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends ConsumerState<ZoneEditorScreen> {
  final List<Offset> _points = [];
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPoint(Offset p) => setState(() => _points.add(p));

  void _undo() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  void _save(AppStrings s) {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.getString('z_editor_need_3'))));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.getString('z_editor_dialog_title')),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: s.getString('z_editor_name'), border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.getString('z_editor_cancel'))),
          FilledButton(
            onPressed: () {
              final name = _nameController.text.isEmpty ? '${s.getString("z_editor_default_name")}${Random().nextInt(100)}' : _nameController.text;
              ref.read(appStateProvider.notifier).addZone(CustomZone(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, points: List.from(_points)));
              _nameController.clear();
              _points.clear();
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.format('z_editor_saved', args: {'name': name}))));
            },
            child: Text(s.getString('z_editor_save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final s = ref.watch(appStringsProvider);
    final persons = state.latestUpdate?.persons ?? [];

    // Map person positions to canvas coordinates
    final personDots = persons.map((p) {
      return _PersonDot(
        id: p.trackId,
        pos: Offset(p.posX * 100 + 200, p.posY * 100 + 250),
        confidence: p.confidence,
      );
    }).toList();

    final isConnected = state.connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.getString('z_editor_title')),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo, tooltip: s.getString('z_editor_undo')),
          IconButton(icon: const Icon(Icons.save), onPressed: () => _save(s), tooltip: s.getString('z_editor_save')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(s.format('z_editor_hint', args: {'count': '${_points.length}'}), style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: isConnected ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    isConnected ? '检测到 ${personDots.length} 人' : '未连接',
                    style: TextStyle(fontSize: 11, color: isConnected ? Colors.green : Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                if (_points.length >= 3)
                  Text(s.getString('z_editor_closable'), style: TextStyle(fontSize: 12, color: Colors.green.shade300)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTapDown: (d) => _addPoint(d.localPosition),
              child: CustomPaint(
                size: Size.infinite,
                painter: _ZonePainter(points: _points, persons: personDots),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonDot {
  final int id;
  final Offset pos;
  final double confidence;
  const _PersonDot({required this.id, required this.pos, required this.confidence});
}

class _ZonePainter extends CustomPainter {
  final List<Offset> points;
  final List<_PersonDot> persons;

  _ZonePainter({required this.points, required this.persons});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid background
    final gridPaint = Paint()..color = Colors.grey.withValues(alpha: 0.1)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw person positions
    final personDot = Paint()..style = PaintingStyle.fill;
    final personCross = Paint()..color = Colors.green.withValues(alpha: 0.5)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (final p in persons) {
      final color = p.confidence > 0.7 ? Colors.green : Colors.orange;
      personDot.color = color.withValues(alpha: 0.6);
      canvas.drawCircle(p.pos, 6, personDot);
      canvas.drawLine(p.pos - const Offset(10, 0), p.pos + const Offset(10, 0), personCross);
      canvas.drawLine(p.pos - const Offset(0, 10), p.pos + const Offset(0, 10), personCross);
      final tp = TextPainter(
        text: TextSpan(text: '${p.id}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, p.pos + const Offset(10, -14));
    }

    // Draw polygon
    final fill = Paint()..color = Colors.cyan.withValues(alpha: 0.1)..style = PaintingStyle.fill;
    final stroke = Paint()..color = Colors.cyan.withValues(alpha: 0.6)..strokeWidth = 2..style = PaintingStyle.stroke;
    final dot = Paint()..color = Colors.cyan..style = PaintingStyle.fill;

    if (points.length >= 3) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    } else if (points.length == 2) {
      canvas.drawLine(points[0], points[1], stroke);
    }
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, dot);
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, points[i] + const Offset(8, -16));
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => old.points != points || old.persons != persons;
}

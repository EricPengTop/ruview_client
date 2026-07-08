import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _addPoint(Offset p) {
    setState(() => _points.add(p));
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() => _points.removeLast());
    }
  }

  void _save() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要 3 个顶点才能构成区域')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('保存区域'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '区域名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = _nameController.text.isEmpty
                  ? '区域${Random().nextInt(100)}'
                  : _nameController.text;
              ref.read(appStateProvider.notifier).addZone(CustomZone(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    points: List.from(_points),
                  ));
              _nameController.clear();
              _points.clear();
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已保存区域 "$name"')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('区域编辑器'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo, tooltip: '撤销'),
          IconButton(icon: const Icon(Icons.save), onPressed: _save, tooltip: '保存'),
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
                Text(
                  '点击画布添加顶点 (${_points.length}个)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
                const Spacer(),
                if (_points.length >= 3)
                  Text('可闭合', style: TextStyle(fontSize: 12, color: Colors.green.shade300)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTapDown: (d) => _addPoint(d.localPosition),
              child: CustomPaint(
                size: Size.infinite,
                painter: _ZonePainter(points: _points),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonePainter extends CustomPainter {
  final List<Offset> points;
  _ZonePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

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
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, points[i] + const Offset(8, -16));
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => old.points != points;
}

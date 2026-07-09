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
  int? _draggingIndex;

  static const double _meterToPixel = 50;
  static const double _offset = 4;

  Offset _toPixel(double mx, double my) => Offset((mx + _offset) * _meterToPixel, (my + _offset) * _meterToPixel);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int? _findNearVertex(Offset pos) {
    for (int i = 0; i < _points.length; i++) {
      if ((_points[i] - pos).distance <= 20) return i;
    }
    return null;
  }

  void _addPoint(Offset p) => setState(() { _points.add(p); _draggingIndex = null; });

  void _startDrag(int index) => setState(() => _draggingIndex = index);

  void _undo() {
    if (_points.isNotEmpty) setState(() { _points.removeLast(); _draggingIndex = null; });
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
        content: TextField(controller: _nameController, decoration: InputDecoration(labelText: s.getString('z_editor_name'), border: const OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.getString('z_editor_cancel'))),
          FilledButton(onPressed: () {
            final name = _nameController.text.isEmpty ? '${s.getString("z_editor_default_name")}${Random().nextInt(100)}' : _nameController.text;
            ref.read(appStateProvider.notifier).addZone(CustomZone(                    id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, points: List.from(_points)));
            _nameController.clear(); _points.clear(); _draggingIndex = null;
            Navigator.pop(context); setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.format('z_editor_saved', args: {'name': name}))));
          }, child: Text(s.getString('z_editor_save'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final s = ref.watch(appStringsProvider);
    final isConnected = state.connectionState.isConnected;
    final persons = state.latestUpdate?.persons ?? [];
    final signalField = state.latestUpdate?.signalField;
    final nodes = state.latestUpdate?.nodes ?? [];

    final personDots = persons.map((p) => _PersonDot(id: p.trackId, pos: _toPixel(p.posX, p.posY), confidence: p.confidence)).toList();
    final sensorDots = nodes.map((n) => _SensorDot(id: n.nodeId, pos: _toPixel(n.posX, n.posY))).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.getString('z_editor_title')),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo, tooltip: s.getString('z_editor_undo')),
          IconButton(icon: const Icon(Icons.save), onPressed: () => _save(s), tooltip: s.getString('z_editor_save')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Top info bar
        Container(
          padding: const EdgeInsets.all(10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(children: [
            Icon(Icons.touch_app, size: 14, color: Colors.grey.shade400), const SizedBox(width: 6),
            Text(
              _draggingIndex != null ? '拖拽顶点${_draggingIndex! + 1}...' : '双击添加  拖拽移动  共${_points.length}个顶点',
              style: TextStyle(fontSize: 12, color: _draggingIndex != null ? Colors.yellow : Colors.grey.shade400),
            ),
            const Spacer(),
            _infoChip(isConnected ? '检测 ${personDots.length} 人' : '未连接', isConnected ? Colors.green : Colors.grey),
            const SizedBox(width: 6),
            if (sensorDots.isNotEmpty) _infoChip('传感器 ${sensorDots.length}', Colors.blue),
            const SizedBox(width: 6),
            if (_points.length >= 3) _infoChip('可闭合', Colors.green.shade300),
          ]),
        ),
        // Canvas
        Expanded(
            child: InteractiveViewer(
            minScale: 0.5, maxScale: 3.0,
            panEnabled: _draggingIndex == null,
            child: GestureDetector(
              onTapUp: (d) {
                // Don't add if tapped near an existing vertex (let pan handle that)
              },
              onPanStart: (d) {
                final near = _findNearVertex(d.localPosition);
                if (near != null) {
                  _startDrag(near);
                }
              },
              onPanUpdate: (d) {
                if (_draggingIndex != null) {
                  setState(() => _points[_draggingIndex!] = d.localPosition);
                }
              },
              onPanEnd: (_) => setState(() => _draggingIndex = null),
              onDoubleTapDown: (d) {
                final near = _findNearVertex(d.localPosition);
                if (near != null) {
                  // Double tap near vertex: Start dragging
                  _startDrag(near);
                } else {
                  // Double tap empty space: Add new vertex
                  _addPoint(d.localPosition);
                }
              },
              child: CustomPaint(
                size: const Size(400, 400),
                painter: _RoomPainter(points: _points, persons: personDots, sensors: sensorDots, signalField: signalField, draggingIndex: _draggingIndex),
              ),
            ),
          ),
        ),
        // Color legend
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(children: [
            Text('信号弱', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            Expanded(child: _buildLegendGradient()),
            const SizedBox(width: 4),
            Text('信号强', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
      ]),
    );
  }

  Widget _infoChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color)),
  );

  Widget _buildLegendGradient() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      gradient: const LinearGradient(colors: [Color(0xFF1a237e), Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.red]),
    ),
  );
}

class _PersonDot { final int id; final Offset pos; final double confidence; const _PersonDot({required this.id, required this.pos, required this.confidence}); }
class _SensorDot { final int id; final Offset pos; const _SensorDot({required this.id, required this.pos}); }

class _RoomPainter extends CustomPainter {
  final List<Offset> points;
  final List<_PersonDot> persons;
  final List<_SensorDot> sensors;
  final SignalField? signalField;
  final int? draggingIndex;

  _RoomPainter({required this.points, required this.persons, required this.sensors, this.signalField, this.draggingIndex});

  // Color scale: blue (weak) → green → yellow → orange → red (strong)
  static Color _heatColor(double t) {
    if (t <= 0) return const Color(0xFF1a237e); // deep blue
    if (t >= 1) return Colors.red;
    if (t < 0.25) return Color.lerp(const Color(0xFF1a237e), Colors.blue, t * 4)!;
    if (t < 0.5) return Color.lerp(Colors.blue, Colors.green, (t - 0.25) * 4)!;
    if (t < 0.75) return Color.lerp(Colors.green, Colors.orange, (t - 0.5) * 4)!;
    return Color.lerp(Colors.orange, Colors.red, (t - 0.75) * 4)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1: Coordinate axes
    _drawAxes(canvas, size);

    // Layer 2: Heatmap background
    _drawHeatmap(canvas, size);

    // Layer 3: Sensor markers
    _drawSensors(canvas);

    // Layer 4: Person crosshairs
    _drawPersons(canvas);

    // Layer 5: User polygon
    _drawPolygon(canvas);
  }

  void _drawAxes(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 0.5;
    final axisPaint = Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 1;
    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 9);

    // Grid lines every 1 meter
    for (int i = 0; i <= 8; i++) {
      final x = i * 50.0;
      final y = i * 50.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Axis origin lines
    final origin = Offset(200, 200); // (0m, 0m)
    canvas.drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), axisPaint);
    canvas.drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), axisPaint);

    // Axis labels
    for (int m = -4; m <= 4; m++) {
      final x = (m + 4) * 50.0;
      final tp = TextPainter(text: TextSpan(text: '${m}m', style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, origin.dy + 2));
    }
    for (int m = -4; m <= 4; m++) {
      if (m == 0) continue; // skip origin overlap
      final y = (m + 4) * 50.0;
      final tp = TextPainter(text: TextSpan(text: '${m}m', style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(origin.dx + 2, y - tp.height / 2));
    }
  }

  void _drawHeatmap(Canvas canvas, Size size) {
    final field = signalField;
    if (field == null || field.values.isEmpty) return;

    final cellW = size.width / field.width;
    final cellH = size.height / field.height;

    for (int row = 0; row < field.height; row++) {
      for (int col = 0; col < field.width; col++) {
        final val = field.valueAt(col, row);
        final paint = Paint()..color = _heatColor(val).withValues(alpha: 0.75);
        canvas.drawRect(Rect.fromLTWH(col * cellW, (field.height - 1 - row) * cellH, cellW, cellH), paint);
      }
    }
  }

  void _drawSensors(Canvas canvas) {
    for (final s in sensors) {
      final fill = Paint()..color = Colors.blue.withValues(alpha: 0.3)..style = PaintingStyle.fill;
      final border = Paint()..color = Colors.blue..strokeWidth = 1.5..style = PaintingStyle.stroke;
      const rect = Rect.fromLTWH(-7, -7, 14, 14);
      canvas.save();
      canvas.translate(s.pos.dx, s.pos.dy);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
      canvas.restore();

      final tp = TextPainter(text: TextSpan(text: '传感器${s.id}', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, s.pos + const Offset(10, -18));
    }
  }

  void _drawPersons(Canvas canvas) {
    final dot = Paint()..style = PaintingStyle.fill;
    final cross = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (final p in persons) {
      final c = p.confidence > 0.7 ? Colors.green : Colors.orange;
      dot.color = c.withValues(alpha: 0.5);
      cross.color = c;
      canvas.drawCircle(p.pos, 5, dot);
      canvas.drawLine(p.pos - const Offset(8, 0), p.pos + const Offset(8, 0), cross);
      canvas.drawLine(p.pos - const Offset(0, 8), p.pos + const Offset(0, 8), cross);
      final tp = TextPainter(text: TextSpan(text: '${p.id}', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      tp.layout(); tp.paint(canvas, p.pos + const Offset(8, -14));
    }
  }

  void _drawPolygon(Canvas canvas) {
    final fill = Paint()..color = Colors.cyan.withValues(alpha: 0.08)..style = PaintingStyle.fill;
    final stroke = Paint()..color = Colors.cyan.withValues(alpha: 0.5)..strokeWidth = 2..style = PaintingStyle.stroke;
    final dot = Paint()..color = Colors.cyan..style = PaintingStyle.fill;
    final dragDot = Paint()..color = Colors.yellow..style = PaintingStyle.fill;
    final halo = Paint()..color = Colors.yellow.withValues(alpha: 0.3)..style = PaintingStyle.fill;

    if (points.length >= 3) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fill); canvas.drawPath(path, stroke);
    } else if (points.length == 2) {
      canvas.drawLine(points[0], points[1], stroke);
    }
    for (int i = 0; i < points.length; i++) {
      if (i == draggingIndex) {
        canvas.drawCircle(points[i], 10, halo);
        canvas.drawCircle(points[i], 6, dragDot);
      } else {
        canvas.drawCircle(points[i], 4, dot);
      }
      final tp = TextPainter(text: TextSpan(text: '${i + 1}', style: TextStyle(color: i == draggingIndex ? Colors.yellow : Colors.white, fontSize: i == draggingIndex ? 11 : 9, fontWeight: i == draggingIndex ? FontWeight.bold : FontWeight.normal)), textDirection: TextDirection.ltr);
      tp.layout(); tp.paint(canvas, points[i] + const Offset(7, -14));
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.points != points || old.persons != persons || old.sensors != sensors || old.signalField != signalField;
}

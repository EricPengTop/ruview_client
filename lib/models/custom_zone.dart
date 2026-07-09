import 'dart:ui';

/// 用户自定义监控区域
class CustomZone {
  final String id;
  final String name;
  final List<Offset> points;

  const CustomZone({
    required this.id,
    required this.name,
    required this.points,
  });
}

import 'dart:ui';

/// 用户自定义监控区域
class CustomZone {
  /// 唯一标识
  final String id;
  /// 区域名称
  final String name;
  /// 多边形顶点列表 (画布像素坐标)
  final List<Offset> points;

  const CustomZone({required this.id, required this.name, required this.points});
}

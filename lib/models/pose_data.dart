/// COCO 17 人体关键点 (单关节)
class Keypoint {
  /// 关节名 (nose/left_shoulder 等)
  final String name;
  /// X 轴像素坐标
  final double x;
  /// Y 轴像素坐标
  final double y;
  /// Z 轴深度坐标
  final double z;
  /// 关节点置信度 0-1
  final double confidence;

  const Keypoint({required this.name, required this.x, required this.y, required this.z, required this.confidence});

  factory Keypoint.fromJson(Map<String, dynamic> json) => Keypoint(
        name: json['name'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        z: (json['z'] as num?)?.toDouble() ?? 0.0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 单个人员的 17 关节姿态检测结果 (含 XY 空间位置)
class PoseDetection {
  /// 追踪 ID
  final int trackId;
  /// 整体检测置信度 0-1
  final double confidence;
  /// RuView 3D 空间 X 坐标 (米)
  final double posX;
  /// RuView 3D 空间 Y 坐标 (米)
  final double posY;
  /// 17 个 COCO 关键点列表
  final List<Keypoint> keypoints;

  const PoseDetection({required this.trackId, required this.confidence, required this.keypoints, this.posX = 0, this.posY = 0});

  factory PoseDetection.fromJson(Map<String, dynamic> json) {
    final rawKeypoints = json['keypoints'] as List<dynamic>? ?? [];
    final rawPos = json['position'] as List<dynamic>? ?? [];
    return PoseDetection(
      trackId: json['id'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      posX: rawPos.isNotEmpty ? (rawPos[0] as num).toDouble() : 0,
      posY: rawPos.isNotEmpty ? (rawPos[1] as num).toDouble() : 0,
      keypoints: rawKeypoints.map((k) => Keypoint.fromJson(k as Map<String, dynamic>)).toList(),
    );
  }
}

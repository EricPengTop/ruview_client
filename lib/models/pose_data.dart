class Keypoint {
  final String name;
  final double x;
  final double y;
  final double z;
  final double confidence;

  const Keypoint({
    required this.name,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  factory Keypoint.fromJson(Map<String, dynamic> json) => Keypoint(
    name: json['name'] as String? ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0.0,
    y: (json['y'] as num?)?.toDouble() ?? 0.0,
    z: (json['z'] as num?)?.toDouble() ?? 0.0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

class PoseDetection {
  final int trackId;
  final double confidence;
  final List<Keypoint> keypoints;

  const PoseDetection({
    required this.trackId,
    required this.confidence,
    required this.keypoints,
  });

  factory PoseDetection.fromJson(Map<String, dynamic> json) {
    final rawKeypoints = json['keypoints'] as List<dynamic>? ?? [];
    return PoseDetection(
      trackId: json['id'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      keypoints: rawKeypoints
          .map((k) => Keypoint.fromJson(k as Map<String, dynamic>))
          .toList(),
    );
  }
}

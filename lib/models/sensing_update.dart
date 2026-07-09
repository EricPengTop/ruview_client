import 'pose_data.dart';
import 'vital_signs.dart';

class WifiNode {
  final int nodeId;
  final double posX;
  final double posY;
  final double posZ;
  final double rssiDbm;

  const WifiNode({
    required this.nodeId,
    required this.posX,
    required this.posY,
    required this.posZ,
    required this.rssiDbm,
  });

  factory WifiNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as List<dynamic>? ?? [];
    return WifiNode(
      nodeId: json['node_id'] as int? ?? 0,
      posX: pos.isNotEmpty ? (pos[0] as num).toDouble() : 0,
      posY: pos.isNotEmpty ? (pos[1] as num).toDouble() : 0,
      posZ: pos.length > 2 ? (pos[2] as num).toDouble() : 0,
      rssiDbm: (json['rssi_dbm'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SignalField {
  final List<int> gridSize;
  final List<double> values;

  const SignalField({required this.gridSize, required this.values});

  factory SignalField.fromJson(Map<String, dynamic> json) {
    final rawSize = json['grid_size'] as List<dynamic>? ?? [];
    final rawValues = json['values'] as List<dynamic>? ?? [];
    return SignalField(
      gridSize: rawSize.map((e) => e as int).toList(),
      values: rawValues.map((e) => (e as num).toDouble()).toList(),
    );
  }

  int get width => gridSize.isNotEmpty ? gridSize[0] : 20;
  int get height => gridSize.length > 1 ? gridSize[1] : 20;

  double valueAt(int x, int y) {
    if (values.isEmpty) return 0;
    final idx = y * width + x;
    return idx < values.length ? values[idx] : 0;
  }
}

class SensingUpdate {
  final int tick;
  final double timestamp;
  final String source;
  final int estimatedPersons;
  final Classification classification;
  final VitalSigns vitalSigns;
  final Features features;
  final List<PoseDetection> persons;
  final List<WifiNode> nodes;
  final SignalField? signalField;

  const SensingUpdate({
    required this.tick,
    required this.timestamp,
    required this.source,
    required this.estimatedPersons,
    required this.classification,
    required this.vitalSigns,
    required this.features,
    required this.persons,
    this.nodes = const [],
    this.signalField,
  });

  factory SensingUpdate.fromJson(Map<String, dynamic> json) {
    final rawPersons = json['persons'] as List<dynamic>? ?? [];
    final rawNodes = json['nodes'] as List<dynamic>? ?? [];
    final rawField = json['signal_field'] as Map<String, dynamic>?;
    return SensingUpdate(
      tick: json['tick'] as int? ?? 0,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? '',
      estimatedPersons: json['estimated_persons'] as int? ?? 0,
      classification: Classification.fromJson(json['classification'] as Map<String, dynamic>? ?? {}),
      vitalSigns: VitalSigns.fromJson(json['vital_signs'] as Map<String, dynamic>? ?? {}),
      features: Features.fromJson(json['features'] as Map<String, dynamic>? ?? {}),
      persons: rawPersons.map((p) => PoseDetection.fromJson(p as Map<String, dynamic>)).toList(),
      nodes: rawNodes.map((n) => WifiNode.fromJson(n as Map<String, dynamic>)).toList(),
      signalField: rawField != null ? SignalField.fromJson(rawField) : null,
    );
  }
}

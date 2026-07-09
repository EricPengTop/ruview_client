import 'pose_data.dart';
import 'vital_signs.dart';

/// WiFi 传感器节点信息 (位置 + 信号强度)
class WifiNode {
  /// 节点 ID
  final int nodeId;
  /// 3D X 坐标 (米)
  final double posX;
  /// 3D Y 坐标 (米)
  final double posY;
  /// 3D Z 坐标 (米)
  final double posZ;
  /// RSSI 信号强度 dBm
  final double rssiDbm;

  const WifiNode({required this.nodeId, required this.posX, required this.posY, required this.posZ, required this.rssiDbm});

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

/// WiFi 信号场强度网格 (2D/3D热力图数据)
class SignalField {
  /// 网格尺寸 [width, height(可选), depth(可选)]
  final List<int> gridSize;
  /// 信号值数组 (行优先)
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

  /// 网格宽度 (X 轴)
  int get width => gridSize.isNotEmpty ? gridSize[0] : 20;
  /// 网格高度 (3D 取 Z 轴, 2D 取 Y 轴)
  int get height => gridSize.length >= 3 ? gridSize[2] : (gridSize.length > 1 ? gridSize[1] : 20);

  /// 按行列索引读取信号值
  double valueAt(int x, int y) {
    if (values.isEmpty) return 0;
    final idx = y * width + x;
    return idx < values.length ? values[idx] : 0;
  }
}

/// RuView 单帧感知数据 (包含人体/节点/信号场/体征/特征)
class SensingUpdate {
  /// 服务端 tick 序号
  final int tick;
  /// Unix 时间戳
  final double timestamp;
  /// 数据源 (simulated / esp32)
  final String source;
  /// 预估人数
  final int estimatedPersons;
  /// 人体存在分类
  final Classification classification;
  /// 生命体征数据
  final VitalSigns vitalSigns;
  /// CSI 信号特征
  final Features features;
  /// 检测到的人体列表
  final List<PoseDetection> persons;
  /// 传感器节点列表
  final List<WifiNode> nodes;
  /// 信号场热力图数据
  final SignalField? signalField;

  const SensingUpdate({
    required this.tick, required this.timestamp, required this.source,
    required this.estimatedPersons, required this.classification,
    required this.vitalSigns, required this.features, required this.persons,
    this.nodes = const [], this.signalField,
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

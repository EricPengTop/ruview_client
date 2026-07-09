/// 生命体征数据 (心率/呼吸率 + 置信度)
class VitalSigns {
  final double breathingRateBpm;
  final double heartRateBpm;
  final double breathingConfidence;
  final double heartbeatConfidence;
  final double signalQuality;

  const VitalSigns({
    required this.breathingRateBpm,
    required this.heartRateBpm,
    required this.breathingConfidence,
    required this.heartbeatConfidence,
    required this.signalQuality,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) => VitalSigns(
    breathingRateBpm: (json['breathing_rate_bpm'] as num?)?.toDouble() ?? 0.0,
    heartRateBpm: (json['heart_rate_bpm'] as num?)?.toDouble() ?? 0.0,
    breathingConfidence:
        (json['breathing_confidence'] as num?)?.toDouble() ?? 0.0,
    heartbeatConfidence:
        (json['heartbeat_confidence'] as num?)?.toDouble() ?? 0.0,
    signalQuality: (json['signal_quality'] as num?)?.toDouble() ?? 0.0,
  );
}

/// 人体存在分类结果
class Classification {
  final bool presence;
  final String motionLevel;
  final double confidence;

  const Classification({
    required this.presence,
    required this.motionLevel,
    required this.confidence,
  });

  factory Classification.fromJson(Map<String, dynamic> json) => Classification(
    presence: json['presence'] as bool? ?? false,
    motionLevel: json['motion_level'] as String? ?? 'unknown',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

/// CSI 信号特征 (RSSI/功率谱/变化点等)
class Features {
  final double meanRssi;
  final double variance;
  final double motionBandPower;
  final double breathingBandPower;
  final double dominantFreqHz;
  final int changePoints;
  final double spectralPower;

  const Features({
    required this.meanRssi,
    required this.variance,
    required this.motionBandPower,
    required this.breathingBandPower,
    required this.dominantFreqHz,
    required this.changePoints,
    required this.spectralPower,
  });

  factory Features.fromJson(Map<String, dynamic> json) => Features(
    meanRssi: (json['mean_rssi'] as num?)?.toDouble() ?? 0.0,
    variance: (json['variance'] as num?)?.toDouble() ?? 0.0,
    motionBandPower: (json['motion_band_power'] as num?)?.toDouble() ?? 0.0,
    breathingBandPower:
        (json['breathing_band_power'] as num?)?.toDouble() ?? 0.0,
    dominantFreqHz: (json['dominant_freq_hz'] as num?)?.toDouble() ?? 0.0,
    changePoints: json['change_points'] as int? ?? 0,
    spectralPower: (json['spectral_power'] as num?)?.toDouble() ?? 0.0,
  );
}

import 'pose_data.dart';
import 'vital_signs.dart';

class SensingUpdate {
  final int tick;
  final double timestamp;
  final String source;
  final int estimatedPersons;
  final Classification classification;
  final VitalSigns vitalSigns;
  final Features features;
  final List<PoseDetection> persons;

  const SensingUpdate({
    required this.tick,
    required this.timestamp,
    required this.source,
    required this.estimatedPersons,
    required this.classification,
    required this.vitalSigns,
    required this.features,
    required this.persons,
  });

  factory SensingUpdate.fromJson(Map<String, dynamic> json) {
    final rawPersons = json['persons'] as List<dynamic>? ?? [];
    return SensingUpdate(
      tick: json['tick'] as int? ?? 0,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? '',
      estimatedPersons: json['estimated_persons'] as int? ?? 0,
      classification: Classification.fromJson(
        json['classification'] as Map<String, dynamic>? ?? {},
      ),
      vitalSigns: VitalSigns.fromJson(
        json['vital_signs'] as Map<String, dynamic>? ?? {},
      ),
      features: Features.fromJson(
        json['features'] as Map<String, dynamic>? ?? {},
      ),
      persons: rawPersons
          .map((p) => PoseDetection.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

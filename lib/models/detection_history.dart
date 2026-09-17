class DetectionItem {
  final String label;
  final double confidence;
  final List<double> boundingBox;

  DetectionItem({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'confidence': confidence,
    'boundingBox': boundingBox,
  };

  factory DetectionItem.fromJson(Map<String, dynamic> json) => DetectionItem(
    label: json['label'],
    confidence: json['confidence'],
    boundingBox: List<double>.from(json['boundingBox']),
  );
}

class DetectionHistoryEntry {
  final String id;
  final DateTime timestamp;
  final List<DetectionItem> detections;
  final String? imagePath;

  DetectionHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.detections,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'detections': detections.map((e) => e.toJson()).toList(),
    'imagePath': imagePath,
  };

  factory DetectionHistoryEntry.fromJson(Map<String, dynamic> json) => DetectionHistoryEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    detections: (json['detections'] as List).map((e) => DetectionItem.fromJson(e)).toList(),
    imagePath: json['imagePath'],
  );
}

// AI Vision — Scene Analyzer
//
// Spatial awareness + heuristic scene understanding.
// Maps object positions to a 3x3 grid, generates Turkish spatial
// descriptions, and infers simple object relationships.

import '../services/detection_stabilizer.dart';

/// Spatial zone in a 3x3 grid
enum SpatialZone {
  topLeft, topCenter, topRight,
  midLeft, center, midRight,
  bottomLeft, bottomCenter, bottomRight,
}

/// Spatial description for a single object
class SpatialInfo {
  final StableDetection detection;
  final SpatialZone zone;
  final String positionTR;   // Turkish position: "sağda", "ortada" etc.
  final String positionEN;   // English position

  SpatialInfo({
    required this.detection,
    required this.zone,
    required this.positionTR,
    required this.positionEN,
  });
}

/// A scene relationship between two objects
class SceneRelation {
  final String descriptionTR;
  final String descriptionEN;

  SceneRelation({required this.descriptionTR, required this.descriptionEN});
}

/// Full scene analysis result
class SceneAnalysis {
  final List<SpatialInfo> spatialInfos;
  final List<SceneRelation> relations;
  final String summaryTR;
  final String summaryEN;

  SceneAnalysis({
    required this.spatialInfos,
    required this.relations,
    required this.summaryTR,
    required this.summaryEN,
  });
}

class SceneAnalyzer {
  DateTime _lastAnalysis = DateTime(2000);
  SceneAnalysis? _cachedAnalysis;

  // Throttle: only re-analyze every 500ms
  static const int _analysisCooldownMs = 500;

  /// Analyze the current set of stable detections.
  SceneAnalysis analyze(List<StableDetection> detections) {
    final now = DateTime.now();
    if (_cachedAnalysis != null &&
        now.difference(_lastAnalysis).inMilliseconds < _analysisCooldownMs) {
      return _cachedAnalysis!;
    }

    // Spatial mapping
    final spatials = detections.map((d) {
      final zone = _getZone(d.smoothBox);
      final posTR = _zoneTurkish(zone);
      final posEN = _zoneEnglish(zone);
      return SpatialInfo(
        detection: d,
        zone: zone,
        positionTR: posTR,
        positionEN: posEN,
      );
    }).toList();

    // Scene relationships
    final relations = _inferRelations(detections);

    // Scene summary
    final summaryTR = _buildSummaryTR(detections);
    final summaryEN = _buildSummaryEN(detections);

    _cachedAnalysis = SceneAnalysis(
      spatialInfos: spatials,
      relations: relations,
      summaryTR: summaryTR,
      summaryEN: summaryEN,
    );
    _lastAnalysis = now;
    return _cachedAnalysis!;
  }

  /// Get spatial description for a specific detection (for TTS)
  String getSpatialDescription(StableDetection d, bool turkish) {
    final zone = _getZone(d.smoothBox);
    return turkish ? _zoneTurkish(zone) : _zoneEnglish(zone);
  }

  SpatialZone _getZone(NormBox box) {
    final cx = box.centerX;
    final cy = box.centerY;

    final col = cx < 0.33 ? 0 : (cx < 0.66 ? 1 : 2);
    final row = cy < 0.33 ? 0 : (cy < 0.66 ? 1 : 2);

    const zones = [
      [SpatialZone.topLeft, SpatialZone.topCenter, SpatialZone.topRight],
      [SpatialZone.midLeft, SpatialZone.center, SpatialZone.midRight],
      [SpatialZone.bottomLeft, SpatialZone.bottomCenter, SpatialZone.bottomRight],
    ];
    return zones[row][col];
  }

  String _zoneTurkish(SpatialZone zone) {
    switch (zone) {
      case SpatialZone.topLeft: return 'sol üstte';
      case SpatialZone.topCenter: return 'üstte';
      case SpatialZone.topRight: return 'sağ üstte';
      case SpatialZone.midLeft: return 'solda';
      case SpatialZone.center: return 'ortada';
      case SpatialZone.midRight: return 'sağda';
      case SpatialZone.bottomLeft: return 'sol altta';
      case SpatialZone.bottomCenter: return 'altta';
      case SpatialZone.bottomRight: return 'sağ altta';
    }
  }

  String _zoneEnglish(SpatialZone zone) {
    switch (zone) {
      case SpatialZone.topLeft: return 'top-left';
      case SpatialZone.topCenter: return 'top';
      case SpatialZone.topRight: return 'top-right';
      case SpatialZone.midLeft: return 'left';
      case SpatialZone.center: return 'center';
      case SpatialZone.midRight: return 'right';
      case SpatialZone.bottomLeft: return 'bottom-left';
      case SpatialZone.bottomCenter: return 'bottom';
      case SpatialZone.bottomRight: return 'bottom-right';
    }
  }

  /// Infer simple spatial relationships between pairs of objects.
  List<SceneRelation> _inferRelations(List<StableDetection> detections) {
    final relations = <SceneRelation>[];
    if (detections.length < 2) return relations;

    for (int i = 0; i < detections.length && i < 5; i++) {
      for (int j = i + 1; j < detections.length && j < 5; j++) {
        final a = detections[i];
        final b = detections[j];
        final rel = _checkRelation(a, b);
        if (rel != null) relations.add(rel);
      }
    }
    return relations;
  }

  SceneRelation? _checkRelation(StableDetection a, StableDetection b) {
    final aName = a.className.toLowerCase();
    final bName = b.className.toLowerCase();
    final aBox = a.smoothBox;
    final bBox = b.smoothBox;

    // Check vertical overlap (are they horizontally aligned?)
    final hOverlap = _horizontalOverlap(aBox, bBox);
    // Check if a is above b
    final aAboveB = aBox.bottom < bBox.top + 0.05;
    final bAboveA = bBox.bottom < aBox.top + 0.05;

    // "X masanın üzerinde" (X is on the table)
    final surfaces = ['dining table', 'desk', 'bench'];
    if (surfaces.contains(bName) && aAboveB && hOverlap > 0.3) {
      return SceneRelation(
        descriptionTR: '${_tr(aName)} masanın üzerinde',
        descriptionEN: '${aName} is on the table',
      );
    }
    if (surfaces.contains(aName) && bAboveA && hOverlap > 0.3) {
      return SceneRelation(
        descriptionTR: '${_tr(bName)} masanın üzerinde',
        descriptionEN: '${bName} is on the table',
      );
    }

    // "Kişi oturuyor" (person is sitting)
    if (aName == 'person' && (bName == 'chair' || bName == 'couch') && hOverlap > 0.3) {
      return SceneRelation(
        descriptionTR: 'Bir kişi oturuyor',
        descriptionEN: 'A person is sitting',
      );
    }
    if (bName == 'person' && (aName == 'chair' || aName == 'couch') && hOverlap > 0.3) {
      return SceneRelation(
        descriptionTR: 'Bir kişi oturuyor',
        descriptionEN: 'A person is sitting',
      );
    }

    // "Kişi telefon tutuyor" (person holding phone)
    if (aName == 'person' && bName == 'cell phone' && _isContained(bBox, aBox)) {
      return SceneRelation(
        descriptionTR: 'Kişi telefon tutuyor',
        descriptionEN: 'Person is holding a phone',
      );
    }
    if (bName == 'person' && aName == 'cell phone' && _isContained(aBox, bBox)) {
      return SceneRelation(
        descriptionTR: 'Kişi telefon tutuyor',
        descriptionEN: 'Person is holding a phone',
      );
    }

    // "Kişi laptop kullanıyor"
    if (aName == 'person' && bName == 'laptop' && hOverlap > 0.3) {
      return SceneRelation(
        descriptionTR: 'Kişi laptop kullanıyor',
        descriptionEN: 'Person is using a laptop',
      );
    }

    return null;
  }

  double _horizontalOverlap(NormBox a, NormBox b) {
    final overlapLeft = a.left > b.left ? a.left : b.left;
    final overlapRight = a.right < b.right ? a.right : b.right;
    if (overlapRight <= overlapLeft) return 0;
    final minWidth = a.width < b.width ? a.width : b.width;
    if (minWidth <= 0) return 0;
    return (overlapRight - overlapLeft) / minWidth;
  }

  bool _isContained(NormBox inner, NormBox outer) {
    return inner.left >= outer.left - 0.05 &&
           inner.right <= outer.right + 0.05 &&
           inner.top >= outer.top - 0.05 &&
           inner.bottom <= outer.bottom + 0.05;
  }

  String _tr(String className) {
    // Shortened inline translations for scene descriptions
    const map = {
      'person': 'Kişi', 'car': 'Araba', 'chair': 'Sandalye',
      'cell phone': 'Telefon', 'laptop': 'Laptop', 'bottle': 'Şişe',
      'cup': 'Bardak', 'book': 'Kitap', 'dog': 'Köpek', 'cat': 'Kedi',
      'dining table': 'Masa', 'couch': 'Kanepe', 'tv': 'Televizyon',
      'keyboard': 'Klavye', 'mouse': 'Fare', 'remote': 'Kumanda',
      'backpack': 'Çanta', 'umbrella': 'Şemsiye', 'handbag': 'El çantası',
    };
    return map[className.toLowerCase()] ?? className;
  }

  String _buildSummaryTR(List<StableDetection> detections) {
    if (detections.isEmpty) return 'Sahne boş';
    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.className] = (counts[d.className] ?? 0) + 1;
    }
    final parts = counts.entries.map((e) {
      final name = _tr(e.key);
      return e.value > 1 ? '${e.value} $name' : name;
    }).toList();
    return 'Sahne: ${parts.join(", ")}';
  }

  String _buildSummaryEN(List<StableDetection> detections) {
    if (detections.isEmpty) return 'Scene empty';
    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.className] = (counts[d.className] ?? 0) + 1;
    }
    final parts = counts.entries.map((e) {
      return e.value > 1 ? '${e.value} ${e.key}s' : e.key;
    }).toList();
    return 'Scene: ${parts.join(", ")}';
  }
}

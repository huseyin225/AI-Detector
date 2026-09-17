// AI Vision — Detection Stabilizer v2
//
// Advanced temporal smoothing with velocity prediction,
// persistent object memory, and fast-motion handling.

import 'dart:math';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Normalized bounding box (0–1 coordinates).
class NormBox {
  final double left, top, right, bottom;
  const NormBox(this.left, this.top, this.right, this.bottom);

  double get width => (right - left).abs();
  double get height => (bottom - top).abs();
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get area => width * height;

  NormBox lerp(NormBox other, double t) => NormBox(
    left + (other.left - left) * t,
    top + (other.top - top) * t,
    right + (other.right - right) * t,
    bottom + (other.bottom - bottom) * t,
  );

  NormBox offset(double dx, double dy) => NormBox(
    left + dx, top + dy, right + dx, bottom + dy,
  );
}

/// A stabilized detection that persists across frames.
class StableDetection {
  String className;
  double confidence;
  NormBox smoothBox;
  NormBox rawBox;
  int framesSeen;
  int framesLost;
  DateTime firstSeen;
  DateTime lastSeen;
  bool isNew;

  // Velocity tracking (normalized units per frame)
  double vx;
  double vy;

  // Segmentation mask (if available)
  List<List<double>>? mask;

  // Opacity for fade in/out animation (0.0 - 1.0)
  double opacity;

  StableDetection({
    required this.className,
    required this.confidence,
    required this.smoothBox,
    required this.rawBox,
    this.framesSeen = 1,
    this.framesLost = 0,
    this.isNew = true,
    this.vx = 0,
    this.vy = 0,
    this.mask,
    this.opacity = 0.0,
    DateTime? firstSeen,
    DateTime? lastSeen,
  })  : firstSeen = firstSeen ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now();

  String get distanceEstimate {
    final a = smoothBox.area;
    if (a > 0.25) return 'Yakın';
    if (a > 0.08) return 'Orta';
    return 'Uzak';
  }

  /// Predicted next position based on velocity
  NormBox get predictedBox => smoothBox.offset(vx, vy);
}

/// Object priority tiers
class ObjectPriority {
  static const Map<String, int> _priorities = {
    'person': 10,
    'car': 8, 'truck': 8, 'bus': 8, 'motorcycle': 8, 'bicycle': 7,
    'dog': 6, 'cat': 6, 'bird': 5,
    'cell phone': 5, 'laptop': 5, 'tv': 5,
    'chair': 3, 'couch': 3, 'bed': 3, 'dining table': 3,
    'bottle': 2, 'cup': 2, 'book': 2, 'keyboard': 2,
  };

  static int getPriority(String className) =>
      _priorities[className.toLowerCase()] ?? 1;
}

class DetectionStabilizer {
  final List<StableDetection> _tracked = [];

  // Tuning
  static const double _smoothingFactor = 0.35;
  static const double _velocitySmoothingFactor = 0.3;
  static const double _matchIoUThreshold = 0.15;
  static const double _matchDistThreshold = 0.18;
  static const int _minFramesToShow = 2;
  static const int _maxFramesToKeep = 15;        // Longer memory (was 8)
  static const int _memoryFrames = 45;           // ~3 seconds of persistent memory
  static const double _labelSwitchThreshold = 0.15;

  /// All tracked objects including those recently lost (persistent memory)
  List<StableDetection> get allTracked => List.unmodifiable(_tracked);

  /// Process a new frame of raw YOLO results.
  List<StableDetection> update(List<YOLOResult> rawResults) {
    final now = DateTime.now();

    final incoming = rawResults.map((r) => _IncomingDetection(
      className: r.className,
      confidence: r.confidence,
      box: NormBox(
        r.normalizedBox.left,
        r.normalizedBox.top,
        r.normalizedBox.right,
        r.normalizedBox.bottom,
      ),
      mask: r.mask,
    )).toList();

    final matched = <int>{};
    final usedIncoming = <int>{};

    // Build match candidates
    final matches = <_Match>[];
    for (int i = 0; i < incoming.length; i++) {
      for (int j = 0; j < _tracked.length; j++) {
        // Use predicted position for matching (handles fast motion)
        final targetBox = _tracked[j].framesLost > 0
            ? _tracked[j].predictedBox
            : _tracked[j].smoothBox;
        final score = _matchScore(incoming[i].box, targetBox, _tracked[j].className, incoming[i].className);
        if (score > 0) {
          matches.add(_Match(i, j, score));
        }
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));

    for (final m in matches) {
      if (usedIncoming.contains(m.incomingIdx) || matched.contains(m.trackedIdx)) continue;

      final inc = incoming[m.incomingIdx];
      final trk = _tracked[m.trackedIdx];

      // Compute velocity from center movement
      final newCx = inc.box.centerX;
      final newCy = inc.box.centerY;
      final oldCx = trk.smoothBox.centerX;
      final oldCy = trk.smoothBox.centerY;
      final newVx = newCx - oldCx;
      final newVy = newCy - oldCy;
      trk.vx = trk.vx * (1 - _velocitySmoothingFactor) + newVx * _velocitySmoothingFactor;
      trk.vy = trk.vy * (1 - _velocitySmoothingFactor) + newVy * _velocitySmoothingFactor;

      trk.rawBox = inc.box;
      trk.smoothBox = trk.smoothBox.lerp(inc.box, _smoothingFactor);
      trk.confidence = trk.confidence * (1 - _smoothingFactor) + inc.confidence * _smoothingFactor;
      trk.framesSeen++;
      trk.framesLost = 0;
      trk.lastSeen = now;
      trk.isNew = false;
      trk.mask = inc.mask;

      // Fade in
      trk.opacity = (trk.opacity + 0.3).clamp(0.0, 1.0);

      if (inc.className != trk.className && inc.confidence > trk.confidence + _labelSwitchThreshold) {
        trk.className = inc.className;
      }

      matched.add(m.trackedIdx);
      usedIncoming.add(m.incomingIdx);
    }

    // Unmatched tracked: increment loss, apply velocity drift
    for (int j = 0; j < _tracked.length; j++) {
      if (!matched.contains(j)) {
        _tracked[j].framesLost++;
        // Drift using velocity prediction
        if (_tracked[j].framesLost <= 3) {
          _tracked[j].smoothBox = _tracked[j].smoothBox.offset(
            _tracked[j].vx * 0.5,
            _tracked[j].vy * 0.5,
          );
        }
        // Fade out
        _tracked[j].opacity = (_tracked[j].opacity - 0.15).clamp(0.0, 1.0);
        // Decay velocity
        _tracked[j].vx *= 0.8;
        _tracked[j].vy *= 0.8;
      }
    }

    // New tracked objects
    for (int i = 0; i < incoming.length; i++) {
      if (!usedIncoming.contains(i)) {
        _tracked.add(StableDetection(
          className: incoming[i].className,
          confidence: incoming[i].confidence,
          smoothBox: incoming[i].box,
          rawBox: incoming[i].box,
          firstSeen: now,
          lastSeen: now,
          isNew: true,
          mask: incoming[i].mask,
          opacity: 0.0,
        ));
      }
    }

    // Remove objects lost beyond persistent memory
    _tracked.removeWhere((t) => t.framesLost > _memoryFrames);

    // Return visible detections (past min frames and not too long lost)
    return _tracked
        .where((t) => t.framesSeen >= _minFramesToShow && t.framesLost <= _maxFramesToKeep)
        .toList();
  }

  /// Get detections that just entered the view
  List<StableDetection> getNewEntries() {
    return _tracked.where((t) => t.framesSeen == _minFramesToShow && t.framesLost == 0).toList();
  }

  /// Get recently lost objects (still in memory but not visible)
  List<StableDetection> getRecentlyLost() {
    return _tracked
        .where((t) => t.framesLost > _maxFramesToKeep && t.framesLost <= _memoryFrames)
        .toList();
  }

  /// Full scene summary including visible + recently lost
  String getSceneSummaryTR() {
    final visible = _tracked.where((t) => t.framesSeen >= _minFramesToShow && t.framesLost <= _maxFramesToKeep).toList();
    final lost = getRecentlyLost();
    if (visible.isEmpty && lost.isEmpty) return 'Sahne boş';

    final parts = <String>[];
    if (visible.isNotEmpty) {
      final counts = <String, int>{};
      for (final d in visible) {
        counts[d.className] = (counts[d.className] ?? 0) + 1;
      }
      parts.addAll(counts.entries.map((e) => e.value > 1 ? '${e.value} ${e.key}' : e.key));
    }
    if (lost.isNotEmpty) {
      parts.add('(${lost.length} nesne hafızada)');
    }
    return parts.join(', ');
  }

  double _matchScore(NormBox a, NormBox b, String existingClass, String newClass) {
    final iou = _computeIoU(a, b);
    final dist = _centerDistance(a, b);

    // Increase match distance for fast-moving objects
    final effectiveDistThreshold = _matchDistThreshold;

    if (dist > effectiveDistThreshold && iou < _matchIoUThreshold) return 0;

    double score = iou * 0.5 + (1.0 - (dist / effectiveDistThreshold).clamp(0, 1)) * 0.3;
    // Class matching bonus
    if (existingClass == newClass) score += 0.2;
    return score;
  }

  double _computeIoU(NormBox a, NormBox b) {
    final xA = max(a.left, b.left);
    final yA = max(a.top, b.top);
    final xB = min(a.right, b.right);
    final yB = min(a.bottom, b.bottom);
    final interArea = max(0.0, xB - xA) * max(0.0, yB - yA);
    if (interArea == 0) return 0;
    return interArea / (a.area + b.area - interArea);
  }

  double _centerDistance(NormBox a, NormBox b) {
    final dx = a.centerX - b.centerX;
    final dy = a.centerY - b.centerY;
    return sqrt(dx * dx + dy * dy);
  }

  void reset() => _tracked.clear();
}

class _IncomingDetection {
  final String className;
  final double confidence;
  final NormBox box;
  final List<List<double>>? mask;
  _IncomingDetection({required this.className, required this.confidence, required this.box, this.mask});
}

class _Match {
  final int incomingIdx;
  final int trackedIdx;
  final double score;
  _Match(this.incomingIdx, this.trackedIdx, this.score);
}

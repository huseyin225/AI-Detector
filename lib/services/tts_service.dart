// AI Vision — TTS Service v3 (Natural Turkish + Spatial)
import 'package:flutter_tts/flutter_tts.dart';
import '../core/constants/app_strings.dart';
import 'detection_stabilizer.dart';
import 'scene_analyzer.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final SceneAnalyzer _sceneAnalyzer = SceneAnalyzer();
  final Map<String, DateTime> _lastAnnounced = {};
  bool _isSpeaking = false;
  static const int _cooldownSeconds = 4;
  DateTime _lastAny = DateTime(2000);
  static const int _globalCooldownMs = 1500;
  DateTime _lastScene = DateTime(2000);
  static const int _sceneCooldownMs = 15000;
  bool _lowLightAnnounced = false;

  SceneAnalyzer get sceneAnalyzer => _sceneAnalyzer;

  TtsService() { _initTts(); }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() => _isSpeaking = true);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
    _flutterTts.setCancelHandler(() => _isSpeaking = false);
  }

  Future<void> announceTopDetection(List<StableDetection> dets, bool tr, double thresh) async {
    if (_isSpeaking) return;
    final now = DateTime.now();
    if (now.difference(_lastAny).inMilliseconds < _globalCooldownMs) return;

    final eligible = dets.where((d) => d.confidence >= thresh && d.framesLost == 0).toList();
    if (eligible.isEmpty) return;

    eligible.sort((a, b) {
      final pa = ObjectPriority.getPriority(a.className), pb = ObjectPriority.getPriority(b.className);
      return pa != pb ? pb.compareTo(pa) : b.confidence.compareTo(a.confidence);
    });

    final best = eligible.first;
    final lt = _lastAnnounced[best.className];
    if (lt != null && now.difference(lt).inSeconds < _cooldownSeconds) return;

    _lastAnnounced[best.className] = now;
    _lastAny = now;

    final label = tr ? AppStrings.getTranslation(best.className) : best.className;
    final spatial = _sceneAnalyzer.getSpatialDescription(best, tr);
    final dist = best.distanceEstimate;

    // Natural Turkish patterns
    String msg;
    if (tr) {
      if (best.className == 'person') {
        msg = dist == 'Yakın' ? 'Önünüzde bir insan var' : '$spatial bir insan var';
      } else {
        msg = '$label $spatial bulunuyor';
      }
    } else {
      msg = '$label $spatial, ${_distEN(dist)}';
    }
    await _flutterTts.speak(msg);
  }

  Future<void> announceNewEntry(StableDetection d, bool tr) async {
    if (_isSpeaking) return;
    final now = DateTime.now();
    if (now.difference(_lastAny).inMilliseconds < _globalCooldownMs) return;
    if (ObjectPriority.getPriority(d.className) < 5) return;

    final label = tr ? AppStrings.getTranslation(d.className) : d.className;
    final spatial = _sceneAnalyzer.getSpatialDescription(d, tr);
    final msg = tr ? '$label $spatial göründü' : '$label appeared $spatial';

    _lastAny = now;
    _lastAnnounced[d.className] = now;
    await _flutterTts.speak(msg);
  }

  Future<void> maybeAnnounceSceneSummary(List<StableDetection> dets, bool tr) async {
    if (_isSpeaking) return;
    final now = DateTime.now();
    if (now.difference(_lastScene).inMilliseconds < _sceneCooldownMs) return;
    if (dets.length < 2) return;

    _lastScene = now; _lastAny = now;
    final analysis = _sceneAnalyzer.analyze(dets);
    if (analysis.relations.isNotEmpty) {
      final rel = analysis.relations.first;
      await _flutterTts.speak(tr ? rel.descriptionTR : rel.descriptionEN);
    } else {
      await _flutterTts.speak(tr ? analysis.summaryTR : analysis.summaryEN);
    }
  }

  Future<void> announceLowLight() async {
    if (_isSpeaking || _lowLightAnnounced) return;
    _lowLightAnnounced = true;
    await _flutterTts.speak('Ortam çok karanlık, algılama doğruluğu düşebilir');
  }

  void resetLowLight() => _lowLightAnnounced = false;

  String _distEN(String tr) {
    switch (tr) { case 'Yakın': return 'close'; case 'Orta': return 'medium'; default: return 'far'; }
  }

  Future<void> stop() async { await _flutterTts.stop(); _isSpeaking = false; }
}

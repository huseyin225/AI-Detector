// AI Vision — LLM Scene Description Service
//
// Sends detected objects + positions to Claude API every 3-4 seconds
// to generate natural Turkish scene descriptions.
// Falls back to heuristic descriptions when offline/no API key.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'detection_stabilizer.dart';
import 'scene_analyzer.dart';

class LlmSceneService {
  String _apiKey = '';
  bool _enabled = true;
  String _lastDescription = '';
  DateTime _lastCall = DateTime(2000);
  bool _isProcessing = false;

  static const int _cooldownMs = 3500; // 3.5 seconds between API calls
  static const String _model = 'claude-sonnet-4-20250514';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';

  final SceneAnalyzer _fallback = SceneAnalyzer();

  String get lastDescription => _lastDescription;
  bool get isEnabled => _enabled && _apiKey.isNotEmpty;

  void setApiKey(String key) => _apiKey = key.trim();
  void setEnabled(bool v) => _enabled = v;

  /// Generate scene description. Uses LLM if available, otherwise heuristic.
  Future<String> describeScene(
    List<StableDetection> detections,
    bool useTurkish,
  ) async {
    if (detections.isEmpty) {
      _lastDescription = useTurkish ? 'Sahne boş' : 'Empty scene';
      return _lastDescription;
    }

    final now = DateTime.now();
    if (now.difference(_lastCall).inMilliseconds < _cooldownMs) {
      return _lastDescription;
    }

    // Try LLM first
    if (isEnabled && !_isProcessing) {
      _lastCall = now;
      _isProcessing = true;
      try {
        final result = await _callClaude(detections, useTurkish)
            .timeout(const Duration(seconds: 4));
        _lastDescription = result;
        _isProcessing = false;
        return result;
      } catch (_) {
        _isProcessing = false;
        // Fall through to heuristic
      }
    }

    // Heuristic fallback
    _lastCall = now;
    final analysis = _fallback.analyze(detections);
    _lastDescription = useTurkish ? analysis.summaryTR : analysis.summaryEN;

    // Also include first relation if available
    if (analysis.relations.isNotEmpty) {
      final rel = analysis.relations.first;
      _lastDescription = useTurkish ? rel.descriptionTR : rel.descriptionEN;
    }

    return _lastDescription;
  }

  Future<String> _callClaude(
    List<StableDetection> detections,
    bool useTurkish,
  ) async {
    // Build object list with positions
    final objects = detections.map((d) {
      final cx = d.smoothBox.centerX;
      final cy = d.smoothBox.centerY;
      String pos;
      if (cx < 0.33) {
        pos = cy < 0.33 ? 'sol üst' : (cy < 0.66 ? 'sol' : 'sol alt');
      } else if (cx < 0.66) {
        pos = cy < 0.33 ? 'üst' : (cy < 0.66 ? 'orta' : 'alt');
      } else {
        pos = cy < 0.33 ? 'sağ üst' : (cy < 0.66 ? 'sağ' : 'sağ alt');
      }
      return '${d.className} (${(d.confidence * 100).toInt()}%, $pos, ${d.distanceEstimate})';
    }).join(', ');

    final prompt = useTurkish
        ? 'Kamerada görülen nesneler: $objects. Bu sahneyi doğal bir Türkçe cümleyle açıkla. Kısa ol (1-2 cümle). Sadece açıklamayı yaz, başka bir şey ekleme.'
        : 'Objects in camera view: $objects. Describe this scene naturally in 1-2 sentences. Only write the description.';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 100,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'];
      if (content is List && content.isNotEmpty) {
        return content[0]['text'] as String;
      }
    }

    throw Exception('API error: ${response.statusCode}');
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool _voiceEnabled = true;
  double _threshold = 0.5;
  bool _isDarkMode = true;
  bool _useTurkishLabels = true;
  bool _performanceMode = false;
  bool _showDistance = true;
  bool _entryNotify = true;
  bool _segmentationMode = false;
  bool _sceneSummary = true;
  bool _spatialGuidance = true;
  bool _llmEnabled = false;
  String _llmApiKey = '';
  bool _lowLightWarning = true;
  bool _personTracking = true;

  bool get voiceEnabled => _voiceEnabled;
  double get threshold => _threshold;
  bool get isDarkMode => _isDarkMode;
  bool get useTurkishLabels => _useTurkishLabels;
  bool get performanceMode => _performanceMode;
  bool get showDistance => _showDistance;
  bool get entryNotify => _entryNotify;
  bool get segmentationMode => _segmentationMode;
  bool get sceneSummary => _sceneSummary;
  bool get spatialGuidance => _spatialGuidance;
  bool get llmEnabled => _llmEnabled;
  String get llmApiKey => _llmApiKey;
  bool get lowLightWarning => _lowLightWarning;
  bool get personTracking => _personTracking;

  double get pluginThreshold => _performanceMode ? 0.35 : 0.25;
  double get iouThreshold => _performanceMode ? 0.5 : 0.45;

  SettingsService() { _loadSettings(); }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _voiceEnabled = _prefs.getBool('voice_enabled') ?? true;
    _threshold = _prefs.getDouble('confidence_threshold') ?? 0.5;
    _isDarkMode = _prefs.getBool('dark_mode') ?? true;
    _useTurkishLabels = _prefs.getBool('use_turkish_labels') ?? true;
    _performanceMode = _prefs.getBool('performance_mode') ?? false;
    _showDistance = _prefs.getBool('show_distance') ?? true;
    _entryNotify = _prefs.getBool('entry_notify') ?? true;
    _segmentationMode = _prefs.getBool('segmentation_mode') ?? false;
    _sceneSummary = _prefs.getBool('scene_summary') ?? true;
    _spatialGuidance = _prefs.getBool('spatial_guidance') ?? true;
    _llmEnabled = _prefs.getBool('llm_enabled') ?? false;
    _llmApiKey = _prefs.getString('llm_api_key') ?? '';
    _lowLightWarning = _prefs.getBool('low_light_warning') ?? true;
    _personTracking = _prefs.getBool('person_tracking') ?? true;
    notifyListeners();
  }

  Future<void> _save(String k, dynamic v) async {
    if (v is bool) await _prefs.setBool(k, v);
    if (v is double) await _prefs.setDouble(k, v);
    if (v is String) await _prefs.setString(k, v);
    notifyListeners();
  }

  Future<void> toggleVoice(bool v) async { _voiceEnabled = v; await _save('voice_enabled', v); }
  Future<void> setThreshold(double v) async { _threshold = v; await _save('confidence_threshold', v); }
  Future<void> toggleDarkMode(bool v) async { _isDarkMode = v; await _save('dark_mode', v); }
  Future<void> toggleTurkishLabels(bool v) async { _useTurkishLabels = v; await _save('use_turkish_labels', v); }
  Future<void> togglePerformanceMode(bool v) async { _performanceMode = v; await _save('performance_mode', v); }
  Future<void> toggleShowDistance(bool v) async { _showDistance = v; await _save('show_distance', v); }
  Future<void> toggleEntryNotify(bool v) async { _entryNotify = v; await _save('entry_notify', v); }
  Future<void> toggleSegmentationMode(bool v) async { _segmentationMode = v; await _save('segmentation_mode', v); }
  Future<void> toggleSceneSummary(bool v) async { _sceneSummary = v; await _save('scene_summary', v); }
  Future<void> toggleSpatialGuidance(bool v) async { _spatialGuidance = v; await _save('spatial_guidance', v); }
  Future<void> toggleLlmEnabled(bool v) async { _llmEnabled = v; await _save('llm_enabled', v); }
  Future<void> setLlmApiKey(String v) async { _llmApiKey = v; await _save('llm_api_key', v); }
  Future<void> toggleLowLightWarning(bool v) async { _lowLightWarning = v; await _save('low_light_warning', v); }
  Future<void> togglePersonTracking(bool v) async { _personTracking = v; await _save('person_tracking', v); }
}

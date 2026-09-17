import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_history.dart';

class HistoryService extends ChangeNotifier {
  static const String _historyKey = 'detection_history';
  List<DetectionHistoryEntry> _history = [];

  List<DetectionHistoryEntry> get history => _history;

  HistoryService() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);
    
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _history = decoded.map((e) => DetectionHistoryEntry.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> saveDetection(DetectionHistoryEntry entry) async {
    _history.insert(0, entry); // Add to top
    if (_history.length > 50) {
      _history = _history.sublist(0, 50); // Keep only last 50
    }
    await _saveToPrefs();
  }

  Future<void> deleteEntry(String id) async {
    _history.removeWhere((entry) => entry.id == id);
    await _saveToPrefs();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
    notifyListeners();
  }
}

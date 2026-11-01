import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/match_history_store.dart';

/// Implementação do histórico local de partidas persistido em SharedPreferences
/// sob a chave `match_history_<sessionId>`.
class PrefsMatchHistoryStore implements MatchHistoryStore {
  PrefsMatchHistoryStore({SharedPreferences? preferences})
      : _prefsInstance = preferences;

  final SharedPreferences? _prefsInstance;

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  static const String keyPrefix = 'match_history_';
  static String keyFor(String sessionId) => '$keyPrefix$sessionId';

  @override
  Future<bool> hasSession(String sessionId) async {
    try {
      final prefs = await _prefs;
      return prefs.containsKey(keyFor(sessionId));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readSession(String sessionId) async {
    try {
      final prefs = await _prefs;
      final key = keyFor(sessionId);
      if (!prefs.containsKey(key)) {
        return [];
      }
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error loading local match history: $e');
      return [];
    }
  }

  @override
  Future<void> appendToSession(
    String sessionId,
    Map<String, dynamic> record,
  ) async {
    try {
      final prefs = await _prefs;
      final key = keyFor(sessionId);
      List<dynamic> history = [];
      try {
        if (prefs.containsKey(key)) {
          final raw = prefs.getString(key);
          if (raw != null && raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              history = List<dynamic>.from(decoded);
            }
          }
        }
      } catch (_) {
        history = [];
      }
      history.add(record);
      await prefs.setString(key, jsonEncode(history));
    } catch (e) {
      debugPrint('Error saving local match history: $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/custom_badges_repository.dart';

/// Implementação do repositório de insígnias customizadas persistido em
/// SharedPreferences sob a chave `custom_badges_<groupId>`.
class PrefsCustomBadgesRepository implements CustomBadgesRepository {
  PrefsCustomBadgesRepository({SharedPreferences? preferences})
      : _prefsInstance = preferences;

  final SharedPreferences? _prefsInstance;

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  static String keyFor(String groupId) => 'custom_badges_$groupId';

  @override
  Future<List<Map<String, dynamic>>> getCustomBadges(String groupId) async {
    try {
      final prefs = await _prefs;
      final key = keyFor(groupId);
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
      debugPrint('Error loading custom badges: $e');
      return [];
    }
  }

  @override
  Future<void> saveCustomBadges(
    String groupId,
    List<Map<String, dynamic>> badges,
  ) async {
    try {
      final prefs = await _prefs;
      final key = keyFor(groupId);
      await prefs.setString(key, jsonEncode(badges));
    } catch (e) {
      debugPrint('Error saving custom badges: $e');
    }
  }
}

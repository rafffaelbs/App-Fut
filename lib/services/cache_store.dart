import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Generic read-through cache backed by SharedPreferences.
///
/// This is NOT a source of truth — Supabase always is. A repository should:
///   1. Try to fetch from Supabase.
///   2. On success, call [write] to snapshot the result for offline use.
///   3. On a connectivity failure (not a data/validation error), call [read]
///      to fall back to the last known-good snapshot, and let the caller
///      know the data may be stale (e.g. show an "modo offline" banner).
///
/// Keys are namespaced under `cache:` so they never collide with the legacy
/// SharedPreferences keys still used by the (to-be-retired) local-first
/// storage. Each entry also stores when it was written, so callers can
/// decide whether a cached value is too old to show.
class CacheStore {
  static const String _prefix = 'cache:';

  /// Persists [value] (any JSON-encodable object — Map, List, primitives)
  /// under [key], alongside the time it was written.
  Future<void> write(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = {
      'value': value,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_prefix$key', jsonEncode(envelope));
  }

  /// Reads back the value stored under [key], or null if there's no cache
  /// entry yet (e.g. first launch, never fetched successfully before).
  Future<CachedValue?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.tryParse(envelope['cachedAt']?.toString() ?? '');
      return CachedValue(value: envelope['value'], cachedAt: cachedAt);
    } catch (_) {
      // Corrupted entry — treat as a cache miss rather than crashing.
      return null;
    }
  }

  /// Removes a single cache entry (e.g. after a destructive action where a
  /// stale cached copy would be actively misleading).
  Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Clears every cache entry written by this store, without touching any
  /// other SharedPreferences keys (legacy or otherwise).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

class CachedValue {
  final dynamic value;
  final DateTime? cachedAt;

  const CachedValue({required this.value, this.cachedAt});

  /// Convenience for the common case of a cached list of maps
  /// (e.g. a list of players or sessions).
  List<Map<String, dynamic>> asMapList() {
    if (value is! List) return [];
    return (value as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Convenience for a cached single map (e.g. one group or season).
  Map<String, dynamic>? asMap() {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value as Map);
  }
}

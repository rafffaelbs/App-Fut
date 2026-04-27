List<Map<String, dynamic>> ensurePlayerIds(List<Map<String, dynamic>> players) {
  bool changed = false;
  final normalized = players.map((player) {
    final map = Map<String, dynamic>.from(player);
    final dynamic id = map['id'];
    final String fallbackName = (map['name'] ?? '').toString();
    if (id == null || id.toString().trim().isEmpty) {
      map['id'] = fallbackName;
      changed = true;
    }
    return map;
  }).toList();

  return changed ? normalized : players;
}

String playerIdFromObject(dynamic playerObj) {
  if (playerObj is! Map) return '';
  final dynamic id = playerObj['id'];
  if (id != null && id.toString().trim().isNotEmpty) return id.toString();
  final dynamic legacyName = playerObj['name'];
  return legacyName?.toString() ?? '';
}

String eventPlayerId(dynamic eventObj, String field) {
  if (eventObj is! Map) return '';
  final String idKey = '${field}Id';
  final dynamic explicitId = eventObj[idKey];
  if (explicitId != null && explicitId.toString().trim().isNotEmpty) {
    return explicitId.toString();
  }
  final dynamic legacyValue = eventObj[field];
  return legacyValue?.toString() ?? '';
}

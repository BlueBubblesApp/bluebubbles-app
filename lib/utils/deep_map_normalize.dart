import 'dart:convert';

/// Recursively converts platform-channel / Gson maps into plain Dart JSON maps.
dynamic deepNormalizeJson(dynamic raw) {
  if (raw == null) return null;

  if (raw is String) {
    try {
      return deepNormalizeJson(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  if (raw is Map || raw is List) {
    try {
      return jsonDecode(jsonEncode(raw));
    } catch (_) {
      if (raw is Map) {
        return Map<String, dynamic>.fromEntries(
          raw.entries.map(
            (e) => MapEntry(e.key.toString(), deepNormalizeJson(e.value)),
          ),
        );
      }
      if (raw is List) {
        return raw.map(deepNormalizeJson).toList();
      }
    }
  }

  return raw;
}

Map<String, dynamic>? asStringDynamicMap(dynamic raw) {
  if (raw == null) return null;
  final normalized = deepNormalizeJson(raw);
  if (normalized is Map<String, dynamic>) return normalized;
  if (normalized is Map) return Map<String, dynamic>.from(normalized);
  return null;
}

Map<String, dynamic> asStringDynamicMapRequired(dynamic raw) {
  final map = asStringDynamicMap(raw);
  if (map != null) return map;
  throw FormatException('Expected Map<String, dynamic>, got ${raw.runtimeType}');
}

Map<String, dynamic>? normalizeMethodChannelArguments(dynamic raw) {
  if (raw == null) return null;

  try {
    final normalized = deepNormalizeJson(raw);
    if (normalized is Map<String, dynamic>) return normalized;
    if (normalized is Map) return Map<String, dynamic>.from(normalized);
  } catch (_) {}

  return null;
}
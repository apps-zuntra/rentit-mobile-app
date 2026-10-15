import 'dart:convert';

/// Safely formats furnishing values from Maps, JSON strings, Lists, or raw Strings
/// into clean, user-friendly labels (e.g. "Semi Furnished", "Fully Furnished", "Unfurnished").
String formatFurnishing(dynamic val) {
  if (val == null) return '';
  if (val is Map) {
    if (val.containsKey('type') && val['type'] != null) {
      return formatFurnishing(val['type']);
    }
    if (val.containsKey('furnishing') && val['furnishing'] != null) {
      return formatFurnishing(val['furnishing']);
    }
    if (val.containsKey('furnished')) {
      final isF = val['furnished'] == true || val['furnished'] == 'true';
      return isF ? 'Fully Furnished' : 'Unfurnished';
    }
    if (val.values.isNotEmpty) {
      return formatFurnishing(val.values.first);
    }
  }
  if (val is List) {
    return val
        .map((e) => formatFurnishing(e))
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  String str = val.toString().trim();
  if (str.isEmpty || str.toLowerCase() == 'null') return '';

  // Parse JSON-encoded or pseudo-map strings: '{"type":"Semi Furnished"}' or '{type: Semi Furnished}'
  if (str.startsWith('{') && str.endsWith('}')) {
    try {
      final decoded = jsonDecode(str);
      return formatFurnishing(decoded);
    } catch (_) {}
    final match = RegExp(
      r'(?:type|furnishing)\s*[:=]\s*([^,{}]+)',
      caseSensitive: false,
    ).firstMatch(str);
    if (match != null) {
      str = match.group(1)?.trim() ?? str;
    } else {
      str = str.replaceAll(RegExp(r'[{}\[\]"]'), '').trim();
      final parts = str.split(':');
      if (parts.length > 1) {
        str = parts.sublist(1).join(':').trim();
      }
    }
  }

  str = str.replaceAll('"', '').replaceAll("'", '').trim();

  final lower = str.toLowerCase();
  if (lower == 'semi' || lower == 'semi-furnished' || lower == 'semifurnished') {
    return 'Semi Furnished';
  }
  if (lower == 'full' ||
      lower == 'fully' ||
      lower == 'fully-furnished' ||
      lower == 'fullyfurnished') {
    return 'Fully Furnished';
  }
  if (lower == 'unfurnished' || lower == 'none' || lower == 'no') {
    return 'Unfurnished';
  }

  return str;
}

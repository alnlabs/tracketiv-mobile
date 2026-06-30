/// Safely coerce Supabase/PostgREST JSON into a [List].
List<Map<String, dynamic>> asJsonList(dynamic data) {
  if (data == null) return [];
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (data is Map) {
    return [Map<String, dynamic>.from(data)];
  }
  return [];
}

/// Safely coerce an RPC or row response into a [Map].
Map<String, dynamic> asJsonMap(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  throw FormatException('Expected JSON object, got ${data.runtimeType}');
}

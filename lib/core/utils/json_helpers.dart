/// Safely parses a JSON field that might be [int], [double], or [String]
/// into an [int]. Throws [FormatException] if the value cannot be converted.
int parseIntField(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

extension PostgrestListX on List<dynamic> {
  List<T> mapToModel<T>(T Function(Map<String, dynamic> json) fromJson) {
    return map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}

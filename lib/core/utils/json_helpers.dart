/// Safely parses a JSON field that might be [int], [double], or [String]
/// into an [int]. Throws [FormatException] if the value cannot be converted.
int parseIntField(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

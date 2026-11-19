/// Extension on [List<dynamic>] (Supabase response lists) to map each element
/// to a typed model using a [fromJson] factory constructor.
extension PostgrestListX on List<dynamic> {
  List<T> mapToModel<T>(T Function(Map<String, dynamic> json) fromJson) {
    return map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}

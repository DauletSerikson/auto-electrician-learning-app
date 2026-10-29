/// Strict JSON boundary shared by the practice definitions. No UI imports.
final class JsonData {
  final Map<String, Object?> value;
  final String path;

  JsonData(Object? input, this.path) : value = _object(input, path);

  static Map<String, Object?> _object(Object? input, String path) {
    if (input is! Map<String, Object?>) {
      throw FormatException('$path: expected object');
    }
    return Map.unmodifiable(input);
  }

  Never fail(String message) => throw FormatException('$path: $message');

  void fields(Set<String> required, [Set<String> optional = const {}]) {
    final missing = required.difference(value.keys.toSet());
    final unknown = value.keys.toSet().difference({...required, ...optional});
    if (missing.isNotEmpty || unknown.isNotEmpty) {
      fail('missing $missing, unknown $unknown');
    }
  }

  String text(String key) {
    final input = value[key];
    if (input is! String || input.trim().isEmpty) fail('$key: expected text');
    return input;
  }

  double number(String key) {
    final input = value[key];
    if (input is! num || !input.isFinite) fail('$key: expected finite number');
    return input.toDouble();
  }

  int integer(String key) {
    final input = value[key];
    if (input is! int || input < 1) fail('$key: expected positive integer');
    return input;
  }

  bool flag(String key) {
    final input = value[key];
    if (input is! bool) fail('$key: expected boolean');
    return input;
  }

  List<Object?> list(String key) {
    final input = value[key];
    if (input is! List<Object?>) fail('$key: expected list');
    return List.unmodifiable(input);
  }

  List<String> texts(String key) => List.unmodifiable(
    list(key).map((input) {
      if (input is! String || input.trim().isEmpty) {
        fail('$key: expected nonempty text items');
      }
      return input;
    }),
  );

  JsonData child(String key) => JsonData(value[key], '$path.$key');

  List<JsonData> objects(String key) => [
    for (final (index, input) in list(key).indexed)
      JsonData(input, '$path.$key[$index]'),
  ];

  E enumeration<E extends Enum>(String key, List<E> choices) {
    final input = text(key);
    for (final choice in choices) {
      if (choice.name == input) return choice;
    }
    fail('$key: unsupported $input');
  }
}

Map<String, T> indexedById<T>(
  Iterable<T> items,
  String Function(T) id,
  String path,
) {
  final result = <String, T>{};
  for (final item in items) {
    final key = id(item);
    if (result.containsKey(key)) throw FormatException('$path: duplicate $key');
    result[key] = item;
  }
  if (result.isEmpty) throw FormatException('$path: empty collection');
  return Map.unmodifiable(result);
}

import 'package:kinvo/src/core/storage/key_value_store.dart';

/// A [KeyValueStore] kept in memory, for tests.
final class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  /// When set, every operation throws it, simulating broken platform storage.
  Exception? failWith;

  @override
  Future<String?> read(String key) async {
    _throwIfFailing();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _throwIfFailing();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _throwIfFailing();
    values.remove(key);
  }

  void _throwIfFailing() {
    if (failWith case final error?) throw error;
  }
}

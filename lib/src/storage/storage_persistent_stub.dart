// Stub persistent storage for non-Flutter (pure Dart) environments.
class SharedPreferences {}

class PersistentStorageEngine {
  Future<void> write(String key, String value) async {}
  Future<String?> read(String key) async => null;
  Future<void> remove(String key) async {}
}

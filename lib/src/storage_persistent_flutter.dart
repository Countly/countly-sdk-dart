// Flutter implementation wrapper to access SharedPreferences.
import 'package:shared_preferences/shared_preferences.dart';

class PersistentStorageEngine {
  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> write(String key, String value) async {
    final p = await _getPrefs();
    await p.setString(key, value);
  }

  Future<String?> read(String key) async {
    final p = await _getPrefs();
    return p.getString(key);
  }

  Future<void> remove(String key) async {
    final p = await _getPrefs();
    await p.remove(key);
  }
}

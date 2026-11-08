import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyBaseUrl = 'custom_base_url';
  static const String _keyHistory = 'playback_history';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String getBaseUrl() {
    return _prefs.getString(_keyBaseUrl) ?? 'https://raw.githubusercontent.com/djsevenx1/jinricp-pure-app/main/data';
  }

  Future<bool> setBaseUrl(String url) async {
    return await _prefs.setString(_keyBaseUrl, url);
  }

  List<String> getHistory() {
    return _prefs.getStringList(_keyHistory) ?? [];
  }

  Future<void> addHistory(String videoTitle) async {
    final list = getHistory();
    list.remove(videoTitle);
    list.insert(0, videoTitle);
    if (list.length > 50) {
      list.removeLast();
    }
    await _prefs.setStringList(_keyHistory, list);
  }
}

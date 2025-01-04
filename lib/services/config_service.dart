import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';
import 'package:flutter/foundation.dart';

class ConfigService extends ChangeNotifier {
  static const String _configKey = 'api_config';
  final SharedPreferences _prefs;
  ApiConfig? _config;

  ConfigService(this._prefs) {
    _loadConfig();
  }

  ApiConfig get config => _config ?? _loadConfig();

  Future<void> updateConfig(ApiConfig newConfig) async {
    await saveConfig(newConfig);
    _config = newConfig;
  }

  Future<void> saveConfig(ApiConfig config) async {
    await _prefs.setString(_configKey, jsonEncode(config.toJson()));
    notifyListeners();
  }

  ApiConfig _loadConfig() {
    final String? configStr = _prefs.getString(_configKey);
    if (configStr == null) {
      _config = ApiConfig(
        apiKey: '',
        modelName: '',
        baseUrl: '',
      );
      return _config!;
    }
    _config = ApiConfig.fromJson(jsonDecode(configStr));
    return _config!;
  }
}

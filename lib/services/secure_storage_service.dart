import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Keys
  static const String _keyGroqApiKey = 'groq_api_key';
  static const String _keyWatsonApiKey = 'watson_api_key';
  static const String _keyWatsonProjectId = 'watson_project_id';
  static const String _keyWatsonUrl = 'watson_url';

  Future<void> saveGroqApiKey(String key) async {
    await _storage.write(key: _keyGroqApiKey, value: key);
  }

  Future<String?> getGroqApiKey() async {
    return await _storage.read(key: _keyGroqApiKey);
  }

  Future<void> saveWatsonCredentials({
    required String apiKey,
    required String projectId,
    required String url,
  }) async {
    await _storage.write(key: _keyWatsonApiKey, value: apiKey);
    await _storage.write(key: _keyWatsonProjectId, value: projectId);
    await _storage.write(key: _keyWatsonUrl, value: url);
  }

  Future<Map<String, String?>> getWatsonCredentials() async {
    return {
      'apiKey': await _storage.read(key: _keyWatsonApiKey),
      'projectId': await _storage.read(key: _keyWatsonProjectId),
      'url': await _storage.read(key: _keyWatsonUrl),
    };
  }

  Future<void> clearAllKeys() async {
    await _storage.delete(key: _keyGroqApiKey);
    await _storage.delete(key: _keyWatsonApiKey);
    await _storage.delete(key: _keyWatsonProjectId);
    await _storage.delete(key: _keyWatsonUrl);
  }
}

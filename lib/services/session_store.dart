import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const String _tokenKey = 'eastapp_session_token';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

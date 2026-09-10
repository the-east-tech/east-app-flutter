import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const String _tokenKey = 'eastapp_session_token';
  static const String _companyCodeKey = 'eastapp_company_code';
  static const String _employeeIdKey = 'eastapp_employee_id';
  static const String _passwordKey = 'eastapp_password';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readCompanyCode() => _storage.read(key: _companyCodeKey);

  Future<String?> readEmployeeId() => _storage.read(key: _employeeIdKey);

  Future<String?> readPassword() => _storage.read(key: _passwordKey);

  Future<void> writeCompanyCode(String companyCode) {
    return _storage.write(key: _companyCodeKey, value: companyCode);
  }

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> writeSession({
    required String token,
    required String companyCode,
    required String employeeId,
    required String password,
  }) async {
    await writeCompanyCode(companyCode);
    await _storage.write(key: _employeeIdKey, value: employeeId);
    await _storage.write(key: _passwordKey, value: password);
    await writeToken(token);
  }

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

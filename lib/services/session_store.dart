import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const String _tokenKey = 'flow_session_token';
  static const String _companyCodeKey = 'flow_company_code';
  static const String _employeeIdKey = 'flow_employee_id';
  static const String _passwordKey = 'flow_password';
  static const String _legacyTokenKey = 'eastapp_session_token';
  static const String _legacyCompanyCodeKey = 'eastapp_company_code';
  static const String _legacyEmployeeIdKey = 'eastapp_employee_id';
  static const String _legacyPasswordKey = 'eastapp_password';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  Future<String?> readToken() => _readWithMigration(
        key: _tokenKey,
        legacyKey: _legacyTokenKey,
      );

  Future<String?> readCompanyCode() => _readWithMigration(
        key: _companyCodeKey,
        legacyKey: _legacyCompanyCodeKey,
      );

  Future<String?> readEmployeeId() => _readWithMigration(
        key: _employeeIdKey,
        legacyKey: _legacyEmployeeIdKey,
      );

  Future<String?> readPassword() => _readWithMigration(
        key: _passwordKey,
        legacyKey: _legacyPasswordKey,
      );

  Future<String?> _readWithMigration({
    required String key,
    required String legacyKey,
  }) async {
    final currentValue = await _storage.read(key: key);
    if (currentValue != null) return currentValue;
    final legacyValue = await _storage.read(key: legacyKey);
    if (legacyValue == null) return null;
    await _storage.write(key: key, value: legacyValue);
    await _storage.delete(key: legacyKey);
    return legacyValue;
  }

  Future<void> writeCompanyCode(String companyCode) {
    return _storage.write(key: _companyCodeKey, value: companyCode);
  }

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> writeLoginIdentity({
    required String companyCode,
    required String employeeId,
  }) async {
    await writeCompanyCode(companyCode);
    await _storage.write(key: _employeeIdKey, value: employeeId);
  }

  Future<void> writeSession({
    required String token,
    required String companyCode,
    required String employeeId,
    required String password,
  }) async {
    await writeLoginIdentity(
      companyCode: companyCode,
      employeeId: employeeId,
    );
    await _storage.write(key: _passwordKey, value: password);
    await writeToken(token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _legacyTokenKey);
  }
}

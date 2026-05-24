import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessToken = 'access_token';
  static const _keyAbhaNumber = 'abha_number';
  static const _keyAbhaAddress = 'abha_address';
  static const _keyUserProfile = 'user_profile';
  static const _keyBiometricsEnabled = 'biometrics_enabled';

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  static Future<void> saveAbhaDetails({required String number, required String address}) async {
    await _storage.write(key: _keyAbhaNumber, value: number);
    await _storage.write(key: _keyAbhaAddress, value: address);
  }

  static Future<Map<String, String?>> getAbhaDetails() async {
    return {
      'number': await _storage.read(key: _keyAbhaNumber),
      'address': await _storage.read(key: _keyAbhaAddress),
    };
  }

  static Future<void> saveUserProfile(String profileJson) async {
    await _storage.write(key: _keyUserProfile, value: profileJson);
  }

  static Future<String?> getUserProfile() async {
    return await _storage.read(key: _keyUserProfile);
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricsEnabled, value: enabled.toString());
  }

  static Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _keyBiometricsEnabled);
    return val == 'true';
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

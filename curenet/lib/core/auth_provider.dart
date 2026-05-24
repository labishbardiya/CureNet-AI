import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/abdm_service.dart';
import '../services/secure_storage_service.dart';
import '../core/abdm_crypto.dart';
import '../services/biometric_service.dart';
import '../core/data_mode.dart';
import '../core/persona.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  Map<String, dynamic>? _userProfile;
  String? _error;

  AuthStatus get status => _status;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get error => _error;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Only Arjun is hardcoded (demo persona). ALL other phone numbers
  /// get a dynamic, isolated identity with userId = 'user_<last6digits>'.
  static const String _arjunPhone = '9509958988';

  /// Generate a stable userId from any phone number.
  /// Arjun is special (demo persona), everyone else gets 'user_XXXXXX'.
  static String _phoneToUserId(String phone) {
    if (phone == _arjunPhone) return DataMode.arjunId;
    // Use last 6 digits for a short but unique userId
    final suffix = phone.length >= 6 ? phone.substring(phone.length - 6) : phone;
    return 'user_$suffix';
  }

  /// Generate a display name from phone (editable later in profile)
  static String _phoneToDisplayName(String phone) {
    if (phone == _arjunPhone) return Persona.name;
    final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    return 'User $suffix';
  }

  /// Generate a placeholder ABHA from phone
  static String _phoneToAbha(String phone) {
    if (phone == _arjunPhone) return Persona.abhaNumber;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').padLeft(10, '0');
    final d = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    return '91-${d.substring(0, 4)}-${d.substring(4, 8)}-${d.substring(8)}';
  }

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await SecureStorageService.getAccessToken();
    if (token != null) {
      AbdmService.setAccessToken(token);
      final profileJson = await SecureStorageService.getUserProfile();
      if (profileJson != null) {
        _userProfile = jsonDecode(profileJson);
        
        // Restore the user identity from saved profile
        final savedUserId = _userProfile!['userId']?.toString();
        if (savedUserId != null && savedUserId.isNotEmpty) {
          DataMode.setUser(savedUserId);
        } else if (_userProfile!['name'] == 'Arjun Mishra') {
          DataMode.setUser(DataMode.arjunId);
        }
        
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    }
  }

  // Login flow state (shared with OTP screen via route args)
  String? _lastTxnId;
  String? _lastPublicKey;
  String? _lastMobile;

  String? get lastTxnId => _lastTxnId;
  String? get lastPublicKey => _lastPublicKey;
  String? get lastMobile => _lastMobile;

  Future<void> loginWithMobile(String mobile) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      final keyMap = await AbdmService.getPublicKey();
      final String publicKey = keyMap['publicKey'];
      _lastPublicKey = publicKey;
      _lastMobile = mobile;
      
      final String encryptedMobile = AbdmCrypto.encryptRsa(mobile, publicKey);
      
      try {
        final result = await AbdmService.requestLoginOtp(
          encryptedAbhaIdOrMobile: encryptedMobile,
        );
        _lastTxnId = result['txnId'] as String?;
      } catch (e) {
        // Sandbox fallback — allows testing with OTP 123456
        _lastTxnId = 'demo_txn';
      }
      
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _lastTxnId = 'demo_txn';
      _lastMobile = mobile;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String txnId, String otp, {String flow = 'login', String? publicKey}) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      Map<String, dynamic> result;
      
      // Derive identity from phone number (works for ANY phone)
      final String mobile = _lastMobile ?? '0000000000';
      final String userId = _phoneToUserId(mobile);
      final bool isArjun = (userId == DataMode.arjunId);
      
      // 1. Sandbox bypass for any phone with OTP 123456
      if (otp == '123456' || txnId == 'demo_txn' || txnId == 'dummy_txn') {
        result = {
          'token': 'demo_token_$userId',
          'x-token': 'demo_token_$userId',
          'name': _phoneToDisplayName(mobile),
          'ABHANumber': _phoneToAbha(mobile),
          'healthIdNumber': _phoneToAbha(mobile),
          'mobile': mobile,
          'userId': userId,
        };
      } else {
        // 2. Real ABDM Path
        final String effectivePublicKey = publicKey ?? _lastPublicKey ?? (await AbdmService.getPublicKey())['publicKey'];
        final String encryptedOtp = AbdmCrypto.encryptRsa(otp, effectivePublicKey);
        
        if (flow == 'registration') {
          result = await AbdmService.verifyAadhaarOtpForRegistration(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        } else if (flow == 'registration_mobile') {
          result = await AbdmService.verifyMobileOtp(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        } else {
          result = await AbdmService.verifyLoginOtp(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        }
      }

      // 3. Set the active user identity
      DataMode.setUser(userId);

      // 4. Fetch Profile if token is present
      final String? xToken = result['token'] ?? result['x-token'];
      if (xToken != null) {
        try {
          final profile = await AbdmService.getProfile(xToken: xToken);
          _userProfile = profile;
        } catch (_) {
          _userProfile = result['profile'] ?? {
            'name': result['name'] ?? _phoneToDisplayName(mobile),
            'abha': result['ABHANumber'] ?? result['healthIdNumber'] ?? _phoneToAbha(mobile),
          };
        }
        await SecureStorageService.saveAccessToken(xToken);
      } else if (result['ABHANumber'] != null || result['healthIdNumber'] != null) {
        _userProfile = {
          'name': result['name'] ?? result['firstName'] ?? _phoneToDisplayName(mobile),
          'abha': result['ABHANumber'] ?? result['healthIdNumber'] ?? '',
          'mobile': result['mobile'] ?? mobile,
        };
      } else {
        _userProfile = {
          'name': _phoneToDisplayName(mobile),
          'abha': _phoneToAbha(mobile),
          'txnId': txnId,
        };
      }

      // 5. Inject userId into profile for downstream use
      _userProfile!['userId'] = userId;

      // 6. Arjun gets Persona override, everyone else keeps their generated name (editable in profile)
      if (isArjun) {
        _userProfile!['name'] = Persona.name;
        _userProfile!['abha'] = Persona.abhaNumber;
      }

      await SecureStorageService.saveUserProfile(jsonEncode(_userProfile));
      
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> authenticateWithBiometrics() async {
    final hasBiometrics = await SecureStorageService.isBiometricsEnabled();
    if (!hasBiometrics) return;

    final success = await BiometricService.authenticate(
      reason: 'Confirm your identity to log in to CureNet',
    );

    if (success) {
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> newProfile) async {
    // Preserve the userId
    newProfile['userId'] = _userProfile?['userId'] ?? DataMode.activeUserId;
    _userProfile = newProfile;
    await SecureStorageService.saveUserProfile(jsonEncode(_userProfile));
    notifyListeners();
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();
    _status = AuthStatus.unauthenticated;
    _userProfile = null;
    // Reset to default identity
    DataMode.setUser(DataMode.arjunId);
    notifyListeners();
  }
}

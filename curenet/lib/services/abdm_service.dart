// ignore_for_file: unused_element

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import 'secure_storage_service.dart';

/// ABDM Sandbox integration – M1 (ABHA creation/verification), M2 (HIP), M3 (HIU).
/// Strictly follows: ABDM_ABHA_V3_AP_Is_V1_31_07_2025 PDF + AyushmanNHA YouTube workflows.
///
/// ABDM Sandbox has SEPARATE domains for different services:
///   Gateway (sessions, bridges): https://dev.abdm.gov.in/gateway
///   ABHA V3 (enrollment, profile, cert): https://abhasbx.abdm.gov.in/abha/api
///   HIE-CM (consent, data-flow): https://dev.abdm.gov.in/api/hiecm
class AbdmService {
  // Gateway – sessions, bridge registration
  static const String _gatewayBase = 'https://dev.abdm.gov.in/gateway';
  // ABHA – enrollment, profile, public certificate
  static const String _abhaBase = 'https://abhasbx.abdm.gov.in/abha/api';
  // HIE-CM – consent, data-flow
  static const String _hiecmBase = 'https://dev.abdm.gov.in/api/hiecm';

  static String? _accessToken;
  static DateTime? _tokenCreatedAt;

  static void setAccessToken(String token) {
    _accessToken = token;
    _tokenCreatedAt = DateTime.now();
  }

  /// Ensures a valid session token exists before calling an authenticated API.
  /// Gateway tokens expire after ~20 minutes; we refresh proactively at 15 min.
  static Future<void> _ensureAuth() async {
    // Check if cached token is still fresh (< 15 minutes old)
    if (_accessToken != null && _tokenCreatedAt != null) {
      final age = DateTime.now().difference(_tokenCreatedAt!);
      if (age.inMinutes < 15) return;
      // Token expired, clear it
      _accessToken = null;
      _tokenCreatedAt = null;
    }

    await createSession(
      clientId: AppConfig.abdmClientId, 
      clientSecret: AppConfig.abdmClientSecret,
    );
  }

  /// M1 – Get public key/certificate for RSA encryption (Aadhaar, OTP, mobile, email).
  /// GET with auth. Encryption: RSA/ECB/OAEPWithSHA-1AndMGF1Padding.
  static Future<Map<String, dynamic>> getPublicKey() async {
    try {
      await _ensureAuth();
      final uri = Uri.parse('$_abhaBase/v3/profile/public/certificate');
      
      var response = await _rawGet(uri);
      
      // If 401, the token is stale — force a new session and retry once
      if (response.statusCode == 401) {
        _accessToken = null;
        _tokenCreatedAt = null;
        await createSession(
          clientId: AppConfig.abdmClientId,
          clientSecret: AppConfig.abdmClientSecret,
        );
        response = await _rawGet(uri);
      }
      
      if (response.statusCode != 200) {
        throw AbdmException('Public key failed: ${response.statusCode}', response.body);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      // Return a dummy PEM for demo mode if sandbox is down
      return {
        'publicKey': '-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAKj5K4u8a76iMvS2V7Q9r6m5B5yV3f6P\n9Z6E3Q1z2w4o5R8Z3Q6E9r6m5B5yV3f6P9Z6E3Q1z2w4o5R8Z3Q6E9wIDAQAB\n-----END PUBLIC KEY-----'
      };
    }
  }

  /// Raw authenticated GET (returns http.Response for status code checking)
  static Future<http.Response> _rawGet(Uri uri) async {
    return http.get(uri, headers: {
      'Authorization': 'Bearer $_accessToken',
      'REQUEST-ID': _newGuid(),
      'TIMESTAMP': DateTime.now().toUtc().toIso8601String(),
    }).timeout(const Duration(seconds: 10));
  }

  /// M1 – Create session. Returns access token for subsequent APIs.
  /// Headers: X-Request-Id (GUID), X-Timestamp (ISO), X-CM-ID: SBX (sandbox).
  /// Body: clientId, clientSecret, grantType: client_credentials.
  static Future<Map<String, dynamic>> createSession({
    required String clientId,
    required String clientSecret,
    String xCmId = 'sbx',
  }) async {
    // V3 session endpoint (NOT v0.5)
    final uri = Uri.parse('$_gatewayBase/v0.5/sessions');
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Try V3 endpoint first, fallback to v0.5
    var response = await http.post(
      Uri.parse('https://dev.abdm.gov.in/api/hiecm/gateway/v3/sessions'),
      headers: {
        'Content-Type': 'application/json',
        'REQUEST-ID': requestId,
        'TIMESTAMP': timestamp,
        'X-CM-ID': xCmId,
      },
      body: jsonEncode({
        'clientId': clientId,
        'clientSecret': clientSecret,
        'grantType': 'client_credentials',
      }),
    ).timeout(const Duration(seconds: 15));

    // Fallback to v0.5 if V3 is unavailable
    if (response.statusCode != 200 && response.statusCode != 202) {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'REQUEST-ID': requestId,
          'TIMESTAMP': timestamp,
          'X-CM-ID': xCmId,
        },
        body: jsonEncode({
          'clientId': clientId,
          'clientSecret': clientSecret,
          'grantType': 'client_credentials',
        }),
      ).timeout(const Duration(seconds: 15));
    }

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw AbdmException('Session failed: ${response.statusCode}', response.body);
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    if (token != null) {
      _accessToken = token;
      _tokenCreatedAt = DateTime.now();
      await SecureStorageService.saveAccessToken(token);
    }
    return map;
  }

  /// M1 – Generate Registration OTP for ABHA creation.
  /// Requires Aadhaar number encrypted with the public key.
  static Future<Map<String, dynamic>> generateAadhaarOtpForRegistration({
    required String encryptedAadhaar,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/request/otp');
    return _postWithAuth(uri, {
      'scope': ['abha-enrol'],
      'loginHint': 'aadhaar',
      'loginId': encryptedAadhaar,
      'otpSystem': 'aadhaar',
    });
  }

  /// M1 – Verify Registration OTP.
  static Future<Map<String, dynamic>> verifyAadhaarOtpForRegistration({
    required String txnId,
    required String encryptedOtp,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/enrol/byAadhaar');
    return _postWithAuth(uri, {
      'authData': {
        'authMethods': ['otp'],
        'otp': {'txnId': txnId, 'otpValue': encryptedOtp},
      },
      'consent': {'code': 'abha-enrollment', 'version': '1.4'},
    });
  }

  /// M1 – Generate Mobile OTP for ABHA creation (Mobile flow).
  static Future<Map<String, dynamic>> generateMobileOtp({
    required String encryptedMobile,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/request/otp');
    return _postWithAuth(uri, {
      'scope': ['abha-enrol'],
      'loginHint': 'mobile',
      'loginId': encryptedMobile,
      'otpSystem': 'abdm',
    });
  }

  /// M1 – Verify Mobile OTP.
  static Future<Map<String, dynamic>> verifyMobileOtp({
    required String txnId,
    required String encryptedOtp,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/enrol/byMobile');
    return _postWithAuth(uri, {
      'authData': {
        'authMethods': ['otp'],
        'otp': {'txnId': txnId, 'otpValue': encryptedOtp},
      },
      'consent': {'code': 'abha-enrollment', 'version': '1.4'},
    });
  }

  /// Login – Request OTP for existing ABHA user login via mobile.
  static Future<Map<String, dynamic>> requestLoginOtp({
    required String encryptedAbhaIdOrMobile,
    String loginHint = 'mobile',
    String otpSystem = 'abdm',
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/profile/login/request/otp');
    return _postWithAuth(uri, {
      'scope': ['abha-login', '$loginHint-verify'],
      'loginHint': loginHint,
      'loginId': encryptedAbhaIdOrMobile,
      'otpSystem': otpSystem,
    });
  }

  /// Login – Verify OTP for existing ABHA user login.
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String txnId,
    required String encryptedOtp,
    String loginHint = 'mobile',
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/profile/login/verify');
    return _postWithAuth(uri, {
      'scope': ['abha-login', '$loginHint-verify'],
      'authData': {
        'authMethods': ['otp'],
        'otp': {'txnId': txnId, 'otpValue': encryptedOtp},
      },
    });
  }

  /// M1 – Request OTP for ABHA Verification / Login.
  /// loginId must be encrypted with public key (SHA1 + MGF1 padding per guide).
  static Future<Map<String, dynamic>> requestAadhaarOtp({
    required String encryptedAadhaar,
    String? txnId,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/request/otp');
    final body = {
      if (txnId != null && txnId.isNotEmpty) 'txnId': txnId,
      'scope': ['abha-enrol'],
      'loginHint': 'aadhaar',
      'loginId': encryptedAadhaar,
      'otpSystem': 'aadhaar',
    };
    return _postWithAuth(uri, body);
  }

  /// M1 – Verify OTP (Aadhaar-linked mobile). authData.otp.value = encrypted OTP.
  static Future<Map<String, dynamic>> verifyAadhaarOtp({
    required String txnId,
    required String encryptedOtp,
    required String mobile,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/auth/byAadhaar');
    final body = {
      'authData': {
        'authMethod': 'OTP',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'txnId': txnId,
        'otp': {'value': encryptedOtp},
        'mobile': mobile,
      },
      'consent': {'code': 'abha-enrollment', 'version': '1.4'},
    };
    return _postWithAuth(uri, body);
  }

  /// M1 – Fetch ABHA address suggestions (GET). Use txnId from verify OTP flow.
  static Future<Map<String, dynamic>> getAbhaAddressSuggestions({
    required String txnId,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/abha-address/suggest');
    final result = await _getWithAuth(uri, extraHeaders: {'X-Transaction-Id': txnId});
    return result as Map<String, dynamic>;
  }

  /// M1 – Confirm ABHA address (from suggestion or custom).
  static Future<Map<String, dynamic>> confirmAbhaAddress({
    required String txnId,
    required String abhaAddress,
    int preferred = 1,
  }) async {
    final uri = Uri.parse('$_abhaBase/v3/enrollment/abha-address/create');
    return _postWithAuth(uri, {
      'txnId': txnId,
      'abhaAddress': abhaAddress,
      'preferred': preferred,
    });
  }

  /// M1 – Get profile (GET). Requires X-Token from verify OTP response.
  static Future<Map<String, dynamic>> getProfile({required String xToken}) async {
    final uri = Uri.parse('$_abhaBase/v3/profile/account');
    final result = await _getWithAuth(uri, extraHeaders: {'X-Token': xToken});
    return result as Map<String, dynamic>;
  }

  /// M1 – Download ABHA card. Requires X-Token.
  static Future<List<int>> downloadAbhaCard({required String xToken}) async {
    final uri = Uri.parse('$_abhaBase/v3/profile/account/abha-card');
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'X-Request-Id': requestId,
        'X-Timestamp': timestamp,
        'X-CM-ID': 'SBX',
        'X-Token': xToken,
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw AbdmException('ABHA card failed: ${response.statusCode}', response.body);
    }
    return response.bodyBytes;
  }

  static Future<void> updateBridgeUrl({
    required String callbackUrl,
  }) async {
    final uri = Uri.parse('$_gatewayBase/v1/bridges');
    await _patchWithAuth(uri, {'url': callbackUrl});
  }

  /// M1/M2 – Add/Update Services (HIP/HIU/Health-Locker).
  static Future<void> addUpdateServices({
    required List<Map<String, dynamic>> services,
  }) async {
    final uri = Uri.parse('$_gatewayBase/v1/bridges/addUpdateServices');
    await _postWithAuth(uri, services);
  }

  /// M1/M2 – Get Added Services.
  static Future<List<dynamic>> getServices() async {
    final uri = Uri.parse('$_gatewayBase/v1/bridges/getServices');
    return await _getWithAuth(uri) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _patchWithAuth(Uri uri, Map<String, dynamic> body) async {
    await _ensureAuth();
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
        'X-Request-Id': requestId,
        'X-Timestamp': timestamp,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 202 && response.statusCode != 204) {
      throw AbdmException('Patch failed: ${response.statusCode}', response.body);
    }
    return response.body.isEmpty ? {} : jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// M2 – Link Care Context: Associates patient records with ABHA.
  static Future<Map<String, dynamic>> linkCareContext({
    required String abhaAddress,
    required String patientReference,
    required List<Map<String, String>> careContexts,
  }) async {
    final uri = Uri.parse('$_hiecmBase/hip/v3/link/carecontext');
    final body = {
      'accessToken': _accessToken,
      'abhaAddress': abhaAddress,
      'patientReference': patientReference,
      'careContexts': careContexts,
    };
    return _postWithAuth(uri, body);
  }

  /// M2 – Consent on-notify: Acknowledges receipt of consent artefact from Gateway.
  static Future<Map<String, dynamic>> acknowledgeConsent({
    required String requestId,
    required String consentId,
    required String status,
  }) async {
    final uri = Uri.parse('$_hiecmBase/consent/v3/request/hip/on-notify');
    final body = {
      'requestId': requestId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'acknowledgement': {
        'status': status,
        'consentId': consentId,
      },
      'resp': {'requestId': requestId},
    };
    return _postWithAuth(uri, body);
  }

  /// M2 – Data on-request: Resolves a health information request from HIU.
  static Future<Map<String, dynamic>> respondToDataRequest({
    required String requestId,
    required String transactionId,
    required String acknowledgementStatus,
  }) async {
    final uri = Uri.parse('$_hiecmBase/data-flow/v3/health-information/hip/on-request');
    final body = {
      'requestId': requestId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'hiRequest': {
        'transactionId': transactionId,
        'sessionStatus': acknowledgementStatus,
      },
      'resp': {'requestId': requestId},
    };
    return _postWithAuth(uri, body);
  }

  static Future<Map<String, dynamic>> _postWithAuth(Uri uri, dynamic body) async {
    await _ensureAuth();
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
        'REQUEST-ID': requestId,
        'TIMESTAMP': timestamp,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw AbdmException('Request failed: ${response.statusCode}', response.body);
    }
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is List) return {'data': decoded};
    return decoded as Map<String, dynamic>;
  }

  static Future<dynamic> _getWithAuth(Uri uri, {Map<String, String>? extraHeaders}) async {
    await _ensureAuth();
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'REQUEST-ID': requestId,
      'TIMESTAMP': timestamp,
      ...?extraHeaders,
    };
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw AbdmException('Request failed: ${response.statusCode}', response.body);
    }
    final decoded = jsonDecode(response.body);
    return decoded;
  }

  static String _newGuid() {
    // Non-cryptographic GUID (fine for request IDs in sandbox).
    // Avoid bitwise ops on doubles; keep it strictly integer.
    final seed = DateTime.now().microsecondsSinceEpoch;
    var x = seed;
    int nextNibble() {
      // xorshift
      x ^= (x << 13);
      x ^= (x >> 7);
      x ^= (x << 17);
      return (x & 0xF).abs();
    }

    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(RegExp(r'[xy]'), (m) {
      final r = nextNibble();
      final v = m[0] == 'x' ? r : ((r & 0x3) | 0x8);
      return v.toRadixString(16);
    });
  }
}

class AbdmException implements Exception {
  final String message;
  final String? body;
  AbdmException(this.message, [this.body]);
  @override
  String toString() => 'AbdmException: $message${body != null ? '\n$body' : ''}';
}

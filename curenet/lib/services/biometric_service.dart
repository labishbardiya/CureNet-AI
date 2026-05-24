import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static DateTime? _lastAuthTime;

  /// Checks if the device supports any biometric authentication (Face, Fingerprint).
  static Future<bool> canAuthenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  /// Triggers the biometric prompt.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access your Secure Vault',
    bool useGracePeriod = false,
  }) async {
    if (useGracePeriod && _lastAuthTime != null) {
      final diff = DateTime.now().difference(_lastAuthTime!);
      if (diff.inSeconds < 30) {
        // Extend the grace period on reuse
        _lastAuthTime = DateTime.now();
        return true;
      }
    }

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
      );
      if (didAuthenticate) {
        _lastAuthTime = DateTime.now();
      }
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric Error: $e');
      return false;
    }
  }
}

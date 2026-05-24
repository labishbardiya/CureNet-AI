import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:cryptography/cryptography.dart';

/// Handles ABDM specific Cryptography for Milestone 1
/// Employs RSA OpenSSL encryption with OAEP padding and SHA-1/MGF1 as
/// mandated by the ABDM spec for transmitting PII data.
class AbdmCrypto {

  /// Normalizes the public key string from the ABDM V3 API response into 
  /// a proper PEM format that RSAKeyParser can consume.
  ///
  /// The /v3/profile/public/certificate endpoint returns a JSON with:
  ///   {"publicKey": "MIICIjANBgkq...", "encryptionAlgorithm": "RSA/ECB/..."}
  /// 
  /// The publicKey value is raw Base64 (no PEM headers). We wrap it.
  static String _normalizeToPem(String rawKey) {
    var key = rawKey.trim();

    // If it already has PEM headers, return as-is
    if (key.startsWith('-----BEGIN')) return key;

    // Strip any accidental whitespace/newlines in the base64
    key = key.replaceAll(RegExp(r'\s+'), '');

    // Wrap in PKCS#8 / SPKI public key PEM headers
    final lines = <String>[];
    lines.add('-----BEGIN PUBLIC KEY-----');
    // PEM standard: 64-character lines
    for (var i = 0; i < key.length; i += 64) {
      lines.add(key.substring(i, i + 64 > key.length ? key.length : i + 64));
    }
    lines.add('-----END PUBLIC KEY-----');
    return lines.join('\n');
  }

  /// Encrypts an Aadhaar number, mobile, or OTP using the ABDM Public Key.
  /// Accepts raw Base64, PEM-wrapped public key, or X.509 certificate PEM.
  static String encryptRsa(String plainText, String publicKeyPem) {
    try {
      final pem = _normalizeToPem(publicKeyPem);
      final parser = encrypt.RSAKeyParser();
      final publicKey = parser.parse(pem) as RSAPublicKey;
      
      // ABDM strictly requires OAEP with SHA-1 for Aadhaar transmissions.
      final encrypter = encrypt.Encrypter(encrypt.RSA(
        publicKey: publicKey,
        encoding: encrypt.RSAEncoding.OAEP,
        digest: encrypt.RSADigest.SHA1,
      ));

      final encrypted = encrypter.encrypt(plainText);
      return encrypted.base64;
    } catch (e) {
      throw Exception('ABDM RSA Encryption failed: $e');
    }
  }

  /// Generates an ECDH (X25519) KeyPair for M2 Data Flow
  static Future<SimpleKeyPair> generateEcdhKeyPair() async {
    final algorithm = X25519();
    return await algorithm.newKeyPair();
  }

  /// Performs ECDH Key Exchange and derives a shared secret
  static Future<List<int>> deriveSharedSecret(SimpleKeyPair ownKeyPair, SimplePublicKey remotePublicKey) async {
    final algorithm = X25519();
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey: remotePublicKey,
    );
    return await sharedSecret.extractBytes();
  }

  /// Encrypts data using AES-GCM 256 as required for M2 Data Push
  static Future<encrypt.Encrypted> encryptAesGcm(String plainText, List<int> secretKey, List<int> iv) async {
    final algorithm = AesGcm.with256bits();
    final secretKeyObj = SecretKey(secretKey);
    final box = await algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKeyObj,
      nonce: iv,
    );
    return encrypt.Encrypted(Uint8List.fromList(box.concatenation()));
  }
}

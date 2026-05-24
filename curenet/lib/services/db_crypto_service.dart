import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ═══════════════════════════════════════════════════════════════════
///  Database Encryption Service (AES-256-GCM)
/// ═══════════════════════════════════════════════════════════════════
///
///  Provides application-layer encryption for the ObjectBox clinical
///  database. Sensitive fields (name, value, unit, metadata) are
///  encrypted with AES-256-GCM before being persisted.
///
///  Key Management:
///    - A 256-bit encryption key is generated on first launch
///    - Stored in flutter_secure_storage (backed by Android Keystore
///      / iOS Keychain) — never written to disk in plaintext
///    - Each encryption uses a unique 12-byte random nonce (IV)
///
///  Threat Model:
///    - Protects against physical device extraction / rooted access
///    - Protects against backup snooping (ObjectBox files on disk)
///    - Does NOT protect against in-memory attacks while app is open
///
///  Format: Base64(nonce || ciphertext || mac)
/// ═══════════════════════════════════════════════════════════════════
class DbCryptoService {
  static const _storage = FlutterSecureStorage();
  static const _keyAlias = 'curenet_objectbox_encryption_key';

  static final _algorithm = AesGcm.with256bits();
  static SecretKey? _cachedKey;

  /// Initialize the encryption service — call once at app startup.
  /// Generates a new key if none exists, otherwise loads from secure storage.
  static Future<void> init() async {
    _cachedKey = await _loadOrCreateKey();
  }

  /// Encrypt a plaintext string → Base64-encoded ciphertext.
  /// Returns the original string if it's empty or null-like.
  static Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;

    final key = await _getKey();
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    // Pack as: nonce (12 bytes) + ciphertext + mac (16 bytes)
    final packed = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64.encode(packed);
  }

  /// Decrypt a Base64-encoded ciphertext → plaintext string.
  /// Returns the original string if decryption fails (graceful fallback
  /// for unencrypted legacy data).
  static Future<String> decrypt(String cipherBase64) async {
    if (cipherBase64.isEmpty) return cipherBase64;

    try {
      final key = await _getKey();
      final packed = base64.decode(cipherBase64);

      // Minimum size: 12 (nonce) + 0 (ciphertext) + 16 (mac) = 28
      if (packed.length < 28) return cipherBase64;

      final nonce = packed.sublist(0, 12);
      final mac = Mac(packed.sublist(packed.length - 16));
      final cipherText = packed.sublist(12, packed.length - 16);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: mac,
      );

      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );

      return utf8.decode(decrypted);
    } catch (_) {
      // If decryption fails, the data may be unencrypted legacy data.
      // Return as-is for backward compatibility.
      return cipherBase64;
    }
  }

  // ─── Private Helpers ────────────────────────────────────────────────

  static Future<SecretKey> _getKey() async {
    _cachedKey ??= await _loadOrCreateKey();
    return _cachedKey!;
  }

  static Future<SecretKey> _loadOrCreateKey() async {
    final existing = await _storage.read(key: _keyAlias);

    if (existing != null && existing.isNotEmpty) {
      final keyBytes = base64.decode(existing);
      return SecretKey(keyBytes);
    }

    // Generate a new 256-bit key
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final keyBase64 = base64.encode(keyBytes);

    // Persist to secure storage (Android Keystore / iOS Keychain)
    await _storage.write(key: _keyAlias, value: keyBase64);

    return SecretKey(keyBytes);
  }
}

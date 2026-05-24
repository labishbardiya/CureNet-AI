import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User Identity Management for CureNet.
///
/// Only one special identity exists: 'arjun' (demo persona).
/// ALL other phone numbers get a dynamic, isolated identity.
///
/// Identity determines:
///   - Storage namespace (SharedPreferences keys)
///   - AI context (Persona injected or not)
///   - MongoDB record filtering (userId query param)
class DataMode {
  DataMode._();

  /// Kept for backward compatibility — true only when Arjun is active.
  static final ValueNotifier<bool> isDemo = ValueNotifier<bool>(true);

  /// The active user identity. Determines storage namespace + AI context.
  static String _activeUserId = 'arjun';
  static String get activeUserId => _activeUserId;

  /// The demo persona userId
  static const String arjunId = 'arjun';

  /// Get a namespaced storage key for the current user.
  /// e.g., storageKey('health_records') → 'arjun__health_records'
  static String storageKey(String baseKey) {
    return '${_activeUserId}__$baseKey';
  }

  /// Switch active user identity. Called by AuthProvider on login.
  static void setUser(String userId) {
    _activeUserId = userId;
    isDemo.value = (userId == arjunId);
    _persist();
  }

  /// Load saved preference on app start.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeUserId = prefs.getString('active_user_id') ?? arjunId;
    isDemo.value = (_activeUserId == arjunId);
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_user_id', _activeUserId);
  }
}

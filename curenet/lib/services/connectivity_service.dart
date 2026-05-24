import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// ═══════════════════════════════════════════════════════════════════
///  Connectivity Service — Edge-First Network Detection
/// ═══════════════════════════════════════════════════════════════════
///
///  Provides network state detection for the offline-first architecture.
///
///  Routing hierarchy:
///    1. Local Ollama (edge/workstation) — zero-latency, private
///    2. Backend API (clinic LAN) — low-latency, FHIR pipeline
///    3. Cloud APIs (Groq, ABDM) — requires internet
///
///  Cached for 30 seconds to avoid excessive network probes.
/// ═══════════════════════════════════════════════════════════════════
class ConnectivityService {
  static bool? _hasInternet;
  static bool? _hasOllama;
  static bool? _hasBackend;
  static DateTime? _lastCheck;

  static const Duration _cacheDuration = Duration(seconds: 30);

  /// Check if the device has general internet connectivity.
  static Future<bool> hasInternet() async {
    if (_isCacheValid()) return _hasInternet ?? false;
    await _refreshAll();
    return _hasInternet ?? false;
  }

  /// Check if the local Ollama server (Gemma 4) is reachable.
  static Future<bool> hasOllama() async {
    if (_isCacheValid()) return _hasOllama ?? false;
    await _refreshAll();
    return _hasOllama ?? false;
  }

  /// Check if the CureNet backend is reachable (clinic LAN).
  static Future<bool> hasBackend() async {
    if (_isCacheValid()) return _hasBackend ?? false;
    await _refreshAll();
    return _hasBackend ?? false;
  }

  /// Force a fresh connectivity check (e.g., on network change).
  static Future<void> refresh() async {
    _lastCheck = null;
    await _refreshAll();
  }

  /// Get a human-readable connectivity status string.
  static Future<String> getStatusSummary() async {
    await _refreshAll();
    final parts = <String>[];
    if (_hasOllama == true) parts.add('Gemma4:Edge');
    if (_hasBackend == true) parts.add('Backend:LAN');
    if (_hasInternet == true) parts.add('Cloud:Online');
    if (parts.isEmpty) parts.add('Offline');
    return parts.join(' | ');
  }

  // ─── Private ───────────────────────────────────────────────────

  static bool _isCacheValid() {
    if (_lastCheck == null) return false;
    return DateTime.now().difference(_lastCheck!) < _cacheDuration;
  }

  static Future<void> _refreshAll() async {
    if (_isCacheValid()) return;

    final results = await Future.wait([
      _probeOllama(),
      _probeBackend(),
      _probeInternet(),
    ]);

    _hasOllama = results[0];
    _hasBackend = results[1];
    _hasInternet = results[2];
    _lastCheck = DateTime.now();

    debugPrint('[Connectivity] Ollama=$_hasOllama | Backend=$_hasBackend | Internet=$_hasInternet');
  }

  static Future<bool> _probeOllama() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.ollamaUrl}/v1/models'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _probeBackend() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/ocr/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _probeInternet() async {
    try {
      final response = await http.head(
        Uri.parse('https://api.groq.com'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}

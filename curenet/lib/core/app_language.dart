import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  static const String _storageKey = 'selected_language';
  static const String defaultLanguage = 'English';

  static final ValueNotifier<String> selectedLanguage =
      ValueNotifier<String>(defaultLanguage);

  static const Map<String, String> _nameMap = {
    'english': 'English',
    'hindi': 'Hindi',
    'हिन्दी': 'Hindi',
    'bengali': 'Bengali',
    'বাংলা': 'Bengali',
    'telugu': 'Telugu',
    'తెలుగు': 'Telugu',
    'marathi': 'Marathi',
    'मराठी': 'Marathi',
    'tamil': 'Tamil',
    'தமிழ்': 'Tamil',
    'urdu': 'Urdu',
    'اردو': 'Urdu',
    'gujarati': 'Gujarati',
    'ગુજરાતી': 'Gujarati',
    'kannada': 'Kannada',
    'ಕನ್ನಡ': 'Kannada',
    'odia': 'Odia',
    'ଓଡ଼ିଆ': 'Odia',
    'malayalam': 'Malayalam',
    'മലയാളം': 'Malayalam',
    'punjabi': 'Punjabi',
    'ਪੰਜਾਬੀ': 'Punjabi',
    'assamese': 'Assamese',
    'অসমীয়া': 'Assamese',
    'maithili': 'Maithili',
    'मैथिली': 'Maithili',
    'sanskrit': 'Sanskrit',
    'संस्कृत': 'Sanskrit',
    'nepali': 'Nepali',
    'नेपाली': 'Nepali',
    'sindhi': 'Sindhi',
    'सिंधी': 'Sindhi',
    'konkani': 'Konkani',
    'कोंकणी': 'Konkani',
    'dogri': 'Dogri',
    'डोगरी': 'Dogri',
    'bodo': 'Bodo',
    'बड़ो': 'Bodo',
    'manipuri': 'Manipuri',
    'মৈতৈলোন্': 'Manipuri',
    'kashmiri': 'Kashmiri',
    'کٲشُر': 'Kashmiri',
  };

  static String normalizeLanguage(String? value) {
    if (value == null || value.trim().isEmpty) return defaultLanguage;
    final key = value.trim().toLowerCase();
    return _nameMap[key] ?? defaultLanguage;
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      selectedLanguage.value = normalizeLanguage(stored);
    } catch (_) {
      // Keep app usable even if platform channel is not ready after hot restart.
      selectedLanguage.value = defaultLanguage;
    }
  }

  static Future<void> setLanguage(String language) async {
    final normalized = normalizeLanguage(language);
    selectedLanguage.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, normalized);
    } catch (_) {
      // Ignore storage failure; selected language still updates for current session.
    }
  }

  /// Notify all listeners when the language changes.
  static void notifyLanguageChange() {
    selectedLanguage.notifyListeners();
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';

class BhashiniTranslateService {
  // Step 1: Get pipeline config (service IDs + compute URL)
  static const String _configUrl =
      'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';
  // Step 2: Run inference (compute URL returned by step 1, but we use the default)
  static const String _computeUrl =
      'https://dhruva-api.bhashini.gov.in/services/inference/pipeline';

  // Language code mapping (ISO 639-1)
  static const Map<String, String> _langCodes = {
    'English': 'en', 'Hindi': 'hi', 'Bengali': 'bn', 'Telugu': 'te',
    'Marathi': 'mr', 'Tamil': 'ta', 'Urdu': 'ur', 'Gujarati': 'gu',
    'Kannada': 'kn', 'Odia': 'or', 'Malayalam': 'ml', 'Punjabi': 'pa',
    'Assamese': 'as', 'Maithili': 'mai', 'Sanskrit': 'sa', 'Nepali': 'ne',
    'Sindhi': 'sd', 'Konkani': 'kok', 'Dogri': 'doi', 'Bodo': 'brx',
    'Manipuri': 'mni', 'Kashmiri': 'ks',
  };

  // Cache: {"hi": {"Hello": "नमस्ते"}}
  static Map<String, Map<String, String>> _cache = {};
  static bool _isCacheLoaded = false;

  // Pipeline config cache: {"hi": {"serviceId": "...", "computeUrl": "..."}}
  static final Map<String, Map<String, String>> _pipelineCache = {};

  // Track if Bhashini API is reachable
  static bool _apiAvailable = true;
  static int _consecutiveFailures = 0;

  // ─── Offline fallback translations for critical UI strings ───────────
  static const Map<String, Map<String, String>> _offlineTranslations = {
    'hi': {
      'Home': 'होम', 'Records': 'रिकॉर्ड', 'Share': 'शेयर',
      'ABHAy': 'अभय', 'Access Requests': 'एक्सेस अनुरोध',
      'No Pending Requests': 'कोई लंबित अनुरोध नहीं',
      'Access Granted!': 'एक्सेस दी गई!',
      'Return Home': 'होम पर लौटें',
      'Revoke Access Now': 'एक्सेस रद्द करें',
      'Share with Doctor': 'डॉक्टर के साथ साझा करें',
      'Access expires in 30 minutes': 'एक्सेस 30 मिनट में समाप्त',
      'No pending requests': 'कोई लंबित अनुरोध नहीं',
      'Scan Document': 'दस्तावेज़ स्कैन करें',
      'View Emergency Snapshot': 'आपातकालीन स्नैपशॉट देखें',
      'Show Scan & Share QR': 'क्यूआर स्कैन और शेयर करें',
      'Approve': 'स्वीकार', 'Deny': 'अस्वीकार',
      '✓ Approve': '✓ स्वीकार', '✗ Deny': '✗ अस्वीकार',
      'Doctor Access Request': 'डॉक्टर एक्सेस अनुरोध',
      'THEY WILL SEE': 'वे देखेंगे', 'THEY WILL NOT SEE': 'वे नहीं देखेंगे',
      'Emergency health card summary': 'आपातकालीन स्वास्थ्य कार्ड सारांश',
      'Active medications list': 'सक्रिय दवाओं की सूची',
      'Latest vitals & allergies': 'नवीनतम जीवन-संकेत और एलर्जी',
      'Full prescription details': 'पूर्ण प्रिस्क्रिप्शन विवरण',
      'Personal notes & emergency contacts': 'व्यक्तिगत नोट्स और आपातकालीन संपर्क',
      'Access expires in 30 minutes after approval': 'स्वीकृति के बाद 30 मिनट में एक्सेस समाप्त',
      'Health Records': 'स्वास्थ्य रिकॉर्ड',
      'Emergency Snapshot': 'आपातकालीन स्नैपशॉट',
      'Profile': 'प्रोफ़ाइल', 'Settings': 'सेटिंग्स',
      'Logout': 'लॉग आउट', 'Login': 'लॉग इन',
    },
    'bn': {
      'Home': 'হোম', 'Records': 'রেকর্ড', 'Share': 'শেয়ার',
      'ABHAy': 'অভয়', 'Access Requests': 'অ্যাক্সেস অনুরোধ',
      'Approve': 'অনুমোদন', 'Deny': 'প্রত্যাখ্যান',
      '✓ Approve': '✓ অনুমোদন', '✗ Deny': '✗ প্রত্যাখ্যান',
      'Return Home': 'হোমে ফিরুন',
      'Revoke Access Now': 'এখনই অ্যাক্সেস প্রত্যাহার করুন',
      'Access Granted!': 'অ্যাক্সেস দেওয়া হয়েছে!',
    },
  };

  static Future<void> _loadCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString('bhashini_translation_cache');
      if (cacheJson != null) {
        final decoded = jsonDecode(cacheJson) as Map<String, dynamic>;
        _cache = decoded.map(
            (key, value) => MapEntry(key, Map<String, String>.from(value)));
      }
    } catch (_) {}
    _isCacheLoaded = true;
  }

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bhashini_translation_cache', jsonEncode(_cache));
    } catch (_) {}
  }

  /// Get the ISO 639-1 code for a language name.
  static String _getCode(String language) =>
      _langCodes[language] ?? language.toLowerCase().substring(0, 2);

  /// Step 1: Fetch pipeline config to get serviceId for en→targetLang NMT.
  static Future<Map<String, String>?> _getPipelineConfig(
      String targetLangCode) async {
    if (_pipelineCache.containsKey(targetLangCode)) {
      return _pipelineCache[targetLangCode];
    }

    final apiKey = AppConfig.bhashiniApiKey;
    final userId = AppConfig.bhashiniUserId;
    if (apiKey.isEmpty || userId.isEmpty) {
      debugPrint('[Bhashini] API key or User ID is empty. Translation disabled.');
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_configUrl),
            headers: {
              'Content-Type': 'application/json',
              'ulcaApiKey': apiKey,
              'userID': userId,
            },
            body: jsonEncode({
              'pipelineTasks': [
                {
                  'taskType': 'translation',
                  'config': {
                    'language': {
                      'sourceLanguage': 'en',
                      'targetLanguage': targetLangCode,
                    }
                  }
                }
              ],
              'pipelineRequestConfig': {
                'pipelineId': '64392f96daac500b55c543cd'
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[Bhashini] Pipeline config failed: ${response.statusCode} ${response.body.substring(0, 200)}');
        return null;
      }

      final data = jsonDecode(response.body);
      final configs = data['pipelineResponseConfig'] as List?;
      if (configs == null || configs.isEmpty) return null;

      final taskConfig = configs[0]['config'] as List?;
      if (taskConfig == null || taskConfig.isEmpty) return null;

      final serviceId = taskConfig[0]['serviceId']?.toString() ?? '';
      final callbackUrl =
          data['pipelineInferenceAPIEndPoint']?['callbackUrl']?.toString() ??
              _computeUrl;
      final inferenceKey = data['pipelineInferenceAPIEndPoint']
              ?['inferenceApiKey']
              ?['value']
              ?.toString() ??
          AppConfig.bhashiniAuth;

      final result = {
        'serviceId': serviceId,
        'callbackUrl': callbackUrl,
        'inferenceKey': inferenceKey,
      };
      _pipelineCache[targetLangCode] = result;
      _apiAvailable = true;
      _consecutiveFailures = 0;
      return result;
    } catch (e) {
      debugPrint('[Bhashini] Pipeline config error: $e');
      return null;
    }
  }

  /// Translate UI text from English to the target language.
  static Future<String> translateUiText(
    String text, {
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty) return text;
    if (targetLanguage == 'English' || targetLanguage == 'en') return text;

    await _loadCache();

    // Check persistent cache first
    if (_cache.containsKey(targetLanguage) &&
        _cache[targetLanguage]!.containsKey(text)) {
      return _cache[targetLanguage]![text]!;
    }

    // Check offline fallback translations
    final langCode = _getCode(targetLanguage);
    if (_offlineTranslations.containsKey(langCode) &&
        _offlineTranslations[langCode]!.containsKey(text)) {
      return _offlineTranslations[langCode]![text]!;
    }

    // If API has failed too many times, skip network calls
    if (!_apiAvailable && _consecutiveFailures >= 3) {
      return text; // Return English as fallback
    }

    // Get pipeline config (serviceId + compute URL)
    final config = await _getPipelineConfig(langCode);
    if (config == null) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 3) _apiAvailable = false;
      return text; // Fallback to English
    }

    final callbackUrl = config['callbackUrl'] ?? _computeUrl;
    final inferenceKey = config['inferenceKey'] ?? AppConfig.bhashiniAuth;
    final serviceId = config['serviceId'] ?? '';

    try {
      final response = await http
          .post(
            Uri.parse(callbackUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': inferenceKey,
            },
            body: jsonEncode({
              'pipelineTasks': [
                {
                  'taskType': 'translation',
                  'config': {
                    'language': {
                      'sourceLanguage': 'en',
                      'targetLanguage': langCode,
                    },
                    'serviceId': serviceId,
                  }
                }
              ],
              'inputData': {
                'input': [
                  {'source': text}
                ]
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final outputs = data['pipelineResponse'] as List?;
        if (outputs != null && outputs.isNotEmpty) {
          final outputList = outputs[0]['output'] as List?;
          if (outputList != null && outputList.isNotEmpty) {
            final translated = outputList[0]['target']?.toString() ?? text;
            // Save to cache
            _cache.putIfAbsent(targetLanguage, () => {});
            _cache[targetLanguage]![text] = translated;
            _saveCache(); // Fire and forget
            _consecutiveFailures = 0;
            _apiAvailable = true;
            return translated;
          }
        }
      } else {
        debugPrint('[Bhashini] Inference failed: ${response.statusCode}');
        _consecutiveFailures++;
      }
      return text;
    } catch (e) {
      debugPrint('[Bhashini] Inference error: $e');
      _consecutiveFailures++;
      if (_consecutiveFailures >= 3) _apiAvailable = false;
      return text; // Fallback to original text
    }
  }
}

import 'dart:convert';
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
    if (apiKey.isEmpty || userId.isEmpty) return null;

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

      if (response.statusCode != 200) return null;

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
      return result;
    } catch (_) {
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

    // Check cache first
    if (_cache.containsKey(targetLanguage) &&
        _cache[targetLanguage]!.containsKey(text)) {
      return _cache[targetLanguage]![text]!;
    }

    final targetCode = _getCode(targetLanguage);

    // Get pipeline config (serviceId + compute URL)
    final config = await _getPipelineConfig(targetCode);
    if (config == null) return text; // Fallback to English

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
                      'targetLanguage': targetCode,
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
            return translated;
          }
        }
      }
      return text;
    } catch (e) {
      return text; // Fallback to original text
    }
  }
}

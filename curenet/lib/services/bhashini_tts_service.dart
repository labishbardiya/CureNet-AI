import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_config.dart';

/// Bhashini TTS via ULCA pipeline – 22 Indian languages.
class BhashiniTtsService {
  static const String _configUrl =
      'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';
  static const String _computeUrl =
      'https://dhruva-api.bhashini.gov.in/services/inference/pipeline';

  /// ISO 639-1 language codes for Bhashini.
  static const Map<String, String> _langCodes = {
    'English': 'en', 'Hindi': 'hi', 'Bengali': 'bn', 'Telugu': 'te',
    'Marathi': 'mr', 'Tamil': 'ta', 'Urdu': 'ur', 'Gujarati': 'gu',
    'Kannada': 'kn', 'Odia': 'or', 'Malayalam': 'ml', 'Punjabi': 'pa',
    'Assamese': 'as', 'Maithili': 'mai', 'Sanskrit': 'sa', 'Nepali': 'ne',
    'Sindhi': 'sd', 'Konkani': 'kok', 'Dogri': 'doi', 'Bodo': 'brx',
    'Manipuri': 'mni', 'Kashmiri': 'ks',
  };

  // Pipeline config cache
  static final Map<String, Map<String, String>> _pipelineCache = {};

  /// Normalize language name to Bhashini-supported name.
  static String normalizeLanguage(String? language) {
    if (language == null || language.isEmpty) return 'English';
    final normalized = language.trim();
    // Already in our map
    if (_langCodes.containsKey(normalized)) return normalized;
    // Try lowercase match
    for (final entry in _langCodes.entries) {
      if (entry.key.toLowerCase() == normalized.toLowerCase()) {
        return entry.key;
      }
    }
    return 'English';
  }

  static String _getCode(String language) =>
      _langCodes[language] ?? language.toLowerCase().substring(0, 2);

  /// Get TTS pipeline config (serviceId + compute URL).
  static Future<Map<String, String>?> _getPipelineConfig(
      String langCode) async {
    final cacheKey = 'tts_$langCode';
    if (_pipelineCache.containsKey(cacheKey)) {
      return _pipelineCache[cacheKey];
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
                  'taskType': 'tts',
                  'config': {
                    'language': {
                      'sourceLanguage': langCode,
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
      _pipelineCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Synthesize speech and play. Returns true if successful.
  static Future<bool> synthesizeAndPlay({
    required String text,
    String? language,
    String gender = 'female',
  }) async {
    final apiKey = AppConfig.bhashiniApiKey;
    if (apiKey.isEmpty) return false;
    if (text.trim().isEmpty) return false;

    final lang = normalizeLanguage(language);
    final langCode = _getCode(lang);

    // Get pipeline config
    final config = await _getPipelineConfig(langCode);
    if (config == null) return false;

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
                  'taskType': 'tts',
                  'config': {
                    'language': {
                      'sourceLanguage': langCode,
                    },
                    'serviceId': serviceId,
                    'gender': gender,
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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final outputs = data['pipelineResponse'] as List?;
      if (outputs == null || outputs.isEmpty) return false;

      final audioList = outputs[0]['audio'] as List?;
      if (audioList == null || audioList.isEmpty) return false;

      final audioBase64 = audioList[0]['audioContent']?.toString();
      if (audioBase64 == null || audioBase64.isEmpty) return false;

      // Decode base64 audio and play
      final bytes = base64Decode(audioBase64);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/bhashini_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(bytes);

      final player = AudioPlayer();
      await player.play(DeviceFileSource(file.path));
      await player.onPlayerComplete.first;
      try {
        await file.delete();
      } catch (_) {
        // Best-effort cleanup
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

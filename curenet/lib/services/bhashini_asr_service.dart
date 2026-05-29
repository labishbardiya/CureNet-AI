import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// Bhashini ASR via ULCA pipeline – 22 Indian languages.
class BhashiniAsrService {
  static const String _configUrl =
      'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';
  static const String _computeUrl =
      'https://dhruva-api.bhashini.gov.in/services/inference/pipeline';

  static const Map<String, String> _langCodes = {
    'English': 'en', 'Hindi': 'hi', 'Bengali': 'bn', 'Telugu': 'te',
    'Marathi': 'mr', 'Tamil': 'ta', 'Urdu': 'ur', 'Gujarati': 'gu',
    'Kannada': 'kn', 'Odia': 'or', 'Malayalam': 'ml', 'Punjabi': 'pa',
    'Assamese': 'as', 'Maithili': 'mai', 'Sanskrit': 'sa', 'Nepali': 'ne',
    'Sindhi': 'sd', 'Konkani': 'kok', 'Dogri': 'doi', 'Bodo': 'brx',
    'Manipuri': 'mni', 'Kashmiri': 'ks',
  };

  static final Map<String, Map<String, String>> _pipelineCache = {};

  static String _getCode(String language) {
    if (language.isEmpty) return 'en';
    return _langCodes[language] ?? language.toLowerCase().substring(0, 2);
  }

  static Future<Map<String, String>?> _getPipelineConfig(String langCode) async {
    final cacheKey = 'asr_$langCode';
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
                  'taskType': 'asr',
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

  /// Send audio file for transcription
  static Future<String?> transcribeAudio(String filePath, {required String language}) async {
    final apiKey = AppConfig.bhashiniApiKey;
    if (apiKey.isEmpty) return null;

    final langCode = _getCode(language);
    final config = await _getPipelineConfig(langCode);
    if (config == null) return null;

    final callbackUrl = config['callbackUrl'] ?? _computeUrl;
    final inferenceKey = config['inferenceKey'] ?? AppConfig.bhashiniAuth;
    final serviceId = config['serviceId'] ?? '';

    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

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
                  'taskType': 'asr',
                  'config': {
                    'language': {
                      'sourceLanguage': langCode,
                    },
                    'serviceId': serviceId,
                    'audioFormat': 'wav',
                    'samplingRate': 16000
                  }
                }
              ],
              'inputData': {
                'audio': [
                  {'audioContent': base64Audio}
                ]
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[Bhashini ASR] Error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final outputs = data['pipelineResponse'] as List?;
      if (outputs == null || outputs.isEmpty) return null;

      final outputList = outputs[0]['output'] as List?;
      if (outputList == null || outputList.isEmpty) return null;

      final transcribedText = outputList[0]['source']?.toString();
      return transcribedText;
    } catch (e) {
      debugPrint('[Bhashini ASR] Exception: $e');
      return null;
    }
  }
}

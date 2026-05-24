import 'package:flutter_tts/flutter_tts.dart';
import '../services/bhashini_tts_service.dart';
import 'app_config.dart';
import 'app_language.dart';
import '../services/bhashini_translate_service.dart';

/// Voice readout for Abhya – Bhashini TTS (22 Indian languages) with flutter_tts fallback.
class VoiceHelper {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static String? lastError;

  static Future<void> init() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.setLanguage("en-IN");
    _initialized = true;
  }

  /// Speak [text] in [language] (e.g. "English", "Hindi"). Uses Bhashini if API key is set, else flutter_tts.
  /// Automatically translates [text] to the target language before speaking.
  static Future<bool> speak(String text, {String? language}) async {
    if (text.trim().isEmpty) return false;
    await init();
    lastError = null;

    final lang = language ?? AppLanguage.selectedLanguage.value;
    String spokenText = text;
    
    // Translate text before sending to TTS
    if (lang != 'English') {
      try {
        spokenText = await BhashiniTranslateService.translateUiText(text, targetLanguage: lang);
      } catch (_) {}
    }

    if (AppConfig.hasBhashiniKey) {
      final ok = await BhashiniTtsService.synthesizeAndPlay(
        text: spokenText,
        language: lang,
        gender: 'female',
      );
      if (ok) return true;
      lastError = 'Voice failed. Check internet or Bhashini API key.';
    }
    if (lang != 'English') {
      await _tts.setLanguage(_flutterTtsLangCode(lang));
    } else {
      await _tts.setLanguage("en-IN");
    }
    final result = await _tts.speak(spokenText);
    if (result == 1 || result == "1" || result == "success") return true;
    lastError ??= 'Device text-to-speech not available on this device.';
    return false;
  }

  static String _flutterTtsLangCode(String lang) {
    final l = lang.toLowerCase();
    if (l == 'hindi') return 'hi-IN';
    if (l == 'bengali') return 'bn-IN';
    if (l == 'marathi') return 'mr-IN';
    if (l == 'telugu') return 'te-IN';
    if (l == 'tamil') return 'ta-IN';
    if (l == 'gujarati') return 'gu-IN';
    if (l == 'kannada') return 'kn-IN';
    if (l == 'malayalam') return 'ml-IN';
    if (l == 'punjabi') return 'pa-IN';
    return 'en-IN';
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}

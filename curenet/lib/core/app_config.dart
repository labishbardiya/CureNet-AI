/// CureNet app configuration.
/// API keys are read from compile-time env to avoid committing secrets.
///
/// Run with:
///   flutter run --dart-define=BACKEND_URL=http://YOUR_IP:3000
///   (Change BACKEND_URL when switching networks/venues)
class AppConfig {
  /// Groq API Key
  static String get groqApiKey =>
      const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Tavily API Key
  static String get tavilyApiKey =>
      const String.fromEnvironment('TAVILY_API_KEY', defaultValue: '');

  /// ABDM Sandbox Client ID (Bridge ID)
  static String get abdmClientId =>
      const String.fromEnvironment('ABDM_CLIENT_ID', defaultValue: 'SBXID_021821');

  /// ABDM Sandbox Client Secret
  static String get abdmClientSecret =>
      const String.fromEnvironment('ABDM_CLIENT_SECRET', defaultValue: 'e7199d37-43bf-458f-8355-7b0dbe4ee30f');

  /// Bhashini Inference API Key
  static String get bhashiniApiKey =>
      const String.fromEnvironment('BHASHINI_API_KEY', defaultValue: '');

  /// Bhashini User ID
  static String get bhashiniUserId =>
      const String.fromEnvironment('BHASHINI_USER_ID', defaultValue: '');

  /// Bhashini Auth (Authorization)
  static String get bhashiniAuth =>
      const String.fromEnvironment('BHASHINI_AUTH', defaultValue: '');

  static bool get hasBhashiniKey => bhashiniApiKey.isNotEmpty;

  // ─── Backend URL (Render cloud deployment, override with --dart-define) ──
  /// The single source of truth for all backend communication.
  /// Cloud: https://curenet.onrender.com
  /// Local dev: --dart-define=BACKEND_URL=http://127.0.0.1:3000
  static String get backendUrl =>
      const String.fromEnvironment('BACKEND_URL', defaultValue: 'https://curenet.onrender.com');

  /// OCR API endpoint (derived from backendUrl)
  static String get ocrApiUrl => '$backendUrl/api/ocr';

  /// Emergency Card base URL (derived from backendUrl)  
  static String get emergencyBaseUrl => '$backendUrl/api/emergency';

  // ─── Gemma 4 Local Inference (Ollama) ────────────────────────────────────
  /// Local Ollama endpoint for Gemma 4 edge inference.
  /// Default: localhost:11434 (standard Ollama port).
  /// Override with: --dart-define=OLLAMA_URL=http://WORKSTATION_IP:11434
  static String get ollamaUrl =>
      const String.fromEnvironment('OLLAMA_URL', defaultValue: 'http://localhost:11434');
}

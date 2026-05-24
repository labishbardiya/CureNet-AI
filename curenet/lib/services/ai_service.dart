import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/persona.dart';
import 'tavily_service.dart';
import 'ocr_service.dart';
import '../core/data_mode.dart';
import 'connectivity_service.dart';

/// ═══════════════════════════════════════════════════════════════════
///  CureNet AI Service — Gemma 4 Edge-First Architecture
/// ═══════════════════════════════════════════════════════════════════
///
///  Dual-model architecture leveraging the Gemma 4 family:
///
///    • Gemma 4 E4B (Effective 4B) — On-Device / Edge
///      Handles intent classification, title generation, and basic
///      parsing via local Ollama runner. Its Per-Layer Embeddings
///      (PLE) architecture packs frontier-level logic into a tiny
///      memory footprint with 128K context window.
///
///    • Gemma 4 27B — Clinic Workstation / Cloud
///      Handles complex medical reasoning, RAG-augmented chat, and
///      multilingual responses. Deployed on the local clinic
///      workstation via Ollama or routed to cloud (Groq) as fallback.
///
///  Routing:
///    1. Try local Ollama endpoint (edge-first, zero-latency)
///    2. Fallback to Groq cloud API if local is unavailable
/// ═══════════════════════════════════════════════════════════════════
class AiService {
  // ─── Groq Cloud (fallback) ──────────────────────────────────────
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static String get _groqApiKey => AppConfig.groqApiKey;

  // ─── Local Ollama (primary — edge-first) ────────────────────────
  static String get _ollamaApiUrl => '${AppConfig.ollamaUrl}/v1/chat/completions';

  // ─── Gemma 4 Model IDs ─────────────────────────────────
  /// Gemma 4 E4B: lightweight edge model for intent & titles
  static const String _gemma4Small = 'gemma4:e4b';
  /// Gemma 4 31B Dense: full-power model for medical reasoning
  static const String _gemma4Large = 'gemma4:31b';

  // ─── Groq Fallback Model IDs ───────────────────────────────────
  static const String _groqSmallModel = 'llama-3.1-8b-instant';
  static const String _groqLargeModel = 'llama-3.3-70b-versatile';

  /// Track whether Ollama is reachable (cached for session)
  static bool? _ollamaAvailable;

  static String _buildSystemInstruction(String? patientData) {
    return '''
You are ABHAy, a Healthcare Intelligence Assistant for CureNet.

RULES:
1. ONLY use facts from <patient_data>. NEVER invent, assume, or speculate beyond what is provided.
2. If information is not in <patient_data>, say: "This information is not in your current records."
3. Keep responses concise: 3-5 sentences max for simple questions. Use bullet points for lists.
4. Use **bold** for medication names, values, and dates.
5. NEVER suggest new medications or diagnose. Always recommend consulting the listed physician.
6. For emergencies (chest pain, breathing difficulty, sudden paralysis), start with 🚨 **EMERGENCY** and provide the emergency contact.
7. Only answer health/medical/CureNet questions. Politely decline anything else.
8. Be warm and professional. Use simple language.

<patient_data>
${patientData ?? (DataMode.activeUserId == DataMode.arjunId ? Persona.aiContext : 'No patient records uploaded yet. Ask the user to upload prescriptions or lab reports.')}
</patient_data>
''';
  }

  static Future<String> sendMessage(String message, {String language = 'en', String? patientContext}) async {
    final stream = sendMessageStream(message, language: language, patientContext: patientContext);
    String fullResponse = "";
    await for (final chunk in stream) {
      fullResponse += chunk;
    }
    return fullResponse.isNotEmpty ? fullResponse : "I'm having trouble processing that right now.";
  }

  /// ─── Ollama Health Check ──────────────────────────────────────
  /// Uses ConnectivityService for cached, parallel network probing.
  /// Edge-first: always try local Gemma 4 before cloud.
  static Future<bool> _isOllamaAvailable() async {
    if (_ollamaAvailable != null) return _ollamaAvailable!;
    _ollamaAvailable = await ConnectivityService.hasOllama();
    if (_ollamaAvailable!) {
      debugPrint('[AI] ✅ Ollama reachable — using Gemma 4 (edge-first mode)');
    } else {
      debugPrint('[AI] ⚠ Ollama not reachable — falling back to Groq cloud');
    }
    return _ollamaAvailable!;
  }

  /// Check if any AI endpoint is reachable.
  static Future<bool> _isAnyEndpointAvailable() async {
    if (await _isOllamaAvailable()) return true;
    return await ConnectivityService.hasInternet();
  }

  /// ─── Resolve API endpoint & model ─────────────────────────────
  /// Returns (apiUrl, modelId, apiKey) based on availability.
  static Future<({String url, String model, String? apiKey})> _resolveSmallModel() async {
    if (await _isOllamaAvailable()) {
      return (url: _ollamaApiUrl, model: _gemma4Small, apiKey: null);
    }
    return (url: _groqApiUrl, model: _groqSmallModel, apiKey: _groqApiKey);
  }

  static Future<({String url, String model, String? apiKey})> _resolveLargeModel() async {
    if (await _isOllamaAvailable()) {
      return (url: _ollamaApiUrl, model: _gemma4Large, apiKey: null);
    }
    return (url: _groqApiUrl, model: _groqLargeModel, apiKey: _groqApiKey);
  }

  static Map<String, String> _buildHeaders(String? apiKey) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  static Future<String> _identifyIntent(String message) async {
    try {
      final endpoint = await _resolveSmallModel();

      final response = await http.post(
        Uri.parse(endpoint.url),
        headers: _buildHeaders(endpoint.apiKey),
        body: jsonEncode({
          "model": endpoint.model,
          "messages": [
            {
              "role": "system", 
              "content": "Classify the user message into: [MEDICAL_QUERY, GENERAL_CHAT, APP_HELP]. Return ONLY the label."
            },
            {"role": "user", "content": message}
          ],
          "temperature": 0.0,
          "max_tokens": 10,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ?? "MEDICAL_QUERY";
      }
      return "MEDICAL_QUERY";
    } catch (_) {
      return "MEDICAL_QUERY";
    }
  }

  static Stream<String> sendMessageStream(String message, {String language = 'en', String? patientContext}) async* {
    try {
      // ═══ OFFLINE-FIRST CHECK ═══════════════════════════════════
      // If no AI endpoint is reachable, provide offline response
      // from locally stored clinical data.
      if (!await _isAnyEndpointAvailable()) {
        debugPrint('[AI] ⚡ Offline mode — generating response from local records');
        yield* _offlineFallbackStream(message);
        return;
      }

      // ═══ PARALLEL PIPELINE: Run all lookups simultaneously ═══
      // This cuts latency from ~12s to ~4s by not waiting sequentially.
      
      final intentFuture = _identifyIntent(message);
      final webFuture = TavilyService.search("Medical context: $message")
          .timeout(const Duration(seconds: 4))
          .catchError((_) => null);
      final atomsFuture = (patientContext == null)
          ? OcrService.getClinicalAtoms()
              .timeout(const Duration(seconds: 3))
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(<Map<String, dynamic>>[]);
      final semanticFuture = (patientContext == null)
          ? OcrService.searchSemantic(message)
              .timeout(const Duration(seconds: 3))
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(<Map<String, dynamic>>[]);

      // Wait for all in parallel
      final results = await Future.wait([intentFuture, webFuture, atomsFuture, semanticFuture]);

      final String intent = results[0] as String;
      final String? webResult = results[1] as String?;
      final List<Map<String, dynamic>> atoms = results[2] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> semanticResults = results[3] as List<Map<String, dynamic>>;

      debugPrint("AI Routing: Intent=$intent | Web=${webResult != null ? 'Yes' : 'No'} | Atoms=${atoms.length} | Semantic=${semanticResults.length}");

      String webContext = (intent == "MEDICAL_QUERY") ? (webResult ?? "") : "";
      String clinicalAtomsContext = "";

      if (intent == "MEDICAL_QUERY" && patientContext == null) {
        // Build atoms context
        if (atoms.isNotEmpty) {
          clinicalAtomsContext = "[RECENT_CLINICAL_FACTS]\n";
          final recentAtoms = atoms.length > 20 ? atoms.sublist(atoms.length - 20) : atoms;
          for (var a in recentAtoms) {
            final type = a['type'] ?? 'Record';
            final name = a['name'] ?? 'Unknown';
            final val = a['value'] ?? '';
            final unit = a['unit'] ?? '';
            final date = a['date'] ?? 'Unknown';
            clinicalAtomsContext += "- [$date] $type: $name $val $unit\n";
          }
          clinicalAtomsContext += "[/RECENT_CLINICAL_FACTS]\n";
        }

        // Build semantic context
        if (semanticResults.isNotEmpty) {
          clinicalAtomsContext += "\n[RELEVANT_HISTORICAL_CONTEXT]\n";
          for (var r in semanticResults) {
            final abdm = r['abdmContext'] ?? {};
            final display = abdm['displayString'] ?? abdm['documentType'] ?? 'Record';
            clinicalAtomsContext += "- Reference: $display\n";
          }
          clinicalAtomsContext += "[/RELEVANT_HISTORICAL_CONTEXT]\n";
        }
      }

      // Only inject Persona context for demo identity (Arjun Mishra)
      // Live user gets AI context purely from uploaded documents
      final String personaContext = DataMode.activeUserId == DataMode.arjunId 
          ? Persona.aiContext 
          : '';
      final String contextToUse = (patientContext ?? clinicalAtomsContext) + personaContext;

      final String langName = language == 'hi' ? 'Hindi' : (language == 'bn' ? 'Bengali' : 'English');
      
      String userPrompt = "CRITICAL INSTRUCTION: You MUST reply entirely in $langName. \n\n";
      if (webContext.isNotEmpty) {
        userPrompt += "[WEB_SEARCH_CONTEXT]\n$webContext\n[/WEB_SEARCH_CONTEXT]\n\n";
      }
      userPrompt += "User message: $message";

      // ═══ Resolve model: Gemma 4 (local) → Groq (cloud fallback) ═══
      final endpoint = await _resolveLargeModel();
      debugPrint('[AI] Using model: ${endpoint.model} via ${endpoint.url}');

      final request = http.Request('POST', Uri.parse(endpoint.url));
      request.headers.addAll(_buildHeaders(endpoint.apiKey));
      request.body = jsonEncode({
        "model": endpoint.model,
        "messages": [
          {"role": "system", "content": _buildSystemInstruction(contextToUse)},
          {"role": "user", "content": userPrompt}
        ],
        "temperature": 0.5,
        "max_tokens": 1024,
        "stream": true,
      });

      final response = await request.send();
      
      if (response.statusCode == 200) {
        await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.isEmpty) continue;
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6);
            if (dataStr.trim() == '[DONE]') break;
            try {
              final decoded = jsonDecode(dataStr);
              final delta = decoded['choices'][0]['delta']['content'] ?? '';
              yield delta;
            } catch (_) {}
          }
        }
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        // FAILOVER: Switch to smaller model if rate-limited or overloaded
        debugPrint("[AI] Primary model rate-limited. Falling back to smaller model...");
        final fallbackEndpoint = await _resolveSmallModel();

        final fallbackRequest = http.Request('POST', Uri.parse(fallbackEndpoint.url));
        fallbackRequest.headers.addAll(_buildHeaders(fallbackEndpoint.apiKey));
        fallbackRequest.body = jsonEncode({
          "model": fallbackEndpoint.model,
          "messages": [
            {"role": "system", "content": _buildSystemInstruction(contextToUse)},
            {"role": "user", "content": userPrompt}
          ],
          "temperature": 0.5,
          "max_tokens": 1024,
          "stream": true,
        });

        final fallbackResponse = await fallbackRequest.send();
        if (fallbackResponse.statusCode == 200) {
           await for (final line in fallbackResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
            if (line.isEmpty) continue;
            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr.trim() == '[DONE]') break;
              try {
                final decoded = jsonDecode(dataStr);
                final delta = decoded['choices'][0]['delta']['content'] ?? '';
                yield delta;
              } catch (_) {}
            }
          }
        } else {
          yield "I'm having trouble processing that right now.";
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        debugPrint("AI API Error (${response.statusCode}): $errorBody");
        yield "I'm having trouble processing that right now.";
      }
    } catch (e) {
      debugPrint("AI Stream Error: $e");
      yield "Connection error. Please try again later.";
    }
  }

  static Future<String> generateTitle(String firstMessage) async {
    try {
      final endpoint = await _resolveSmallModel();

      final response = await http.post(
        Uri.parse(endpoint.url),
        headers: _buildHeaders(endpoint.apiKey),
        body: jsonEncode({
          "model": endpoint.model,
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful assistant that generates extremely short, concise titles for chat conversations. Return ONLY the title (max 4 words). No punctuation, no quotes."
            },
            {"role": "user", "content": "Summarize this message into a 3-word title: $firstMessage"}
          ],
          "temperature": 0.5,
          "max_tokens": 10,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String title = data['choices'][0]['message']['content'] ?? "New Chat";
        title = title.replaceAll('"', '').replaceAll('.', '').trim();
        return title;
      }
      return "New Chat";
    } catch (e) {
      return "New Chat";
    }
  }

  /// Reset cached Ollama availability (e.g. on network change)
  static void resetOllamaCache() {
    _ollamaAvailable = null;
    ConnectivityService.refresh();
  }

  /// ─── Offline Fallback ──────────────────────────────────────────
  /// When neither local Gemma 4 nor cloud APIs are reachable,
  /// generate a response from locally stored clinical records.
  /// This ensures the app remains useful even without any network.
  static Stream<String> _offlineFallbackStream(String message) async* {
    try {
      final atoms = await OcrService.getClinicalAtoms()
          .timeout(const Duration(seconds: 2))
          .catchError((_) => <Map<String, dynamic>>[]);

      if (atoms.isEmpty) {
        yield "📴 **Offline Mode** — I can't reach the AI service right now. "
              "Your medical records are safely stored locally. "
              "Please reconnect to get AI-powered insights.";
        return;
      }

      // Build a basic response from local clinical data
      yield "📴 **Offline Mode** — Here's what I found in your local records:\n\n";

      final medications = atoms.where((a) => a['type'] == 'medication').toList();
      final observations = atoms.where((a) => a['type'] == 'observation').toList();

      if (medications.isNotEmpty) {
        yield "**Current Medications:**\n";
        for (final med in medications.take(5)) {
          yield "• **${med['name']}** — ${med['value'] ?? ''} (${med['date'] ?? ''})\n";
        }
        yield "\n";
      }

      if (observations.isNotEmpty) {
        yield "**Recent Lab Results:**\n";
        for (final obs in observations.take(5)) {
          yield "• **${obs['name']}**: ${obs['value'] ?? ''} ${obs['unit'] ?? ''} (${obs['date'] ?? ''})\n";
        }
        yield "\n";
      }

      yield "\n_Connect to your clinic network or internet for full AI analysis._";
    } catch (_) {
      yield "📴 **Offline Mode** — Unable to process queries without network access. "
            "Your data is safe locally.";
    }
  }

  static void init() {
    debugPrint("[AI] CureNet AI Service initialized — Gemma 4 edge-first architecture");
    debugPrint("[AI] Primary: Gemma 4 E4B ($_gemma4Small) + 27B ($_gemma4Large) via Ollama");
    debugPrint("[AI] Fallback: Groq Cloud ($_groqSmallModel / $_groqLargeModel)");
    // Pre-warm connectivity cache
    ConnectivityService.refresh();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';

class TavilyService {
  static String get _apiKey => AppConfig.tavilyApiKey;
  static const String _baseUrl = 'https://api.tavily.com/search';

  /// Performs a search using Tavily and returns a string context suitable for an LLM.
  static Future<String?> search(String query) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': _apiKey,
          'query': query,
          'search_depth': 'basic',
          'include_answer': true,
          'max_results': 3,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Use Tavily's generated answer if available
        if (data['answer'] != null && data['answer'].toString().isNotEmpty) {
          return data['answer'];
        }
        
        // Otherwise fallback to combining the search snippets
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final snippets = results.map((e) => e['content']).join('\n\n');
          return "Web Search Context:\n$snippets";
        }
      } else {
        debugPrint('Tavily Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Tavily Exception: $e');
    }
    return null;
  }
}

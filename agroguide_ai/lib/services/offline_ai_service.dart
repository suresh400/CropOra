import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Handles local Ollama AI communication (offline mode).
class OfflineAiService {
  // Ollama endpoint — localhost for web & desktop, 10.0.2.2 for Android emulator
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:11434/api/generate';
    }
    return 'http://127.0.0.1:11434/api/generate';
  }

  // Use a lightweight model for faster responses
  static const String _ollamaModel = 'phi3';

  static const String _systemPrompt =
      'You are a concise agricultural assistant for Indian farmers. '
      'Answer in 3-5 clear sentences. '
      'Give practical advice about crops, fertilizer, irrigation, soil, and weather. '
      'Use simple language.';

  /// Returns true if the Ollama server appears to be running.
  static Future<bool> isOllamaRunning() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:11434/'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ask Ollama. Throws if server is unreachable.
  Future<String> getAnswer(String question) async {
    final prompt = '$_systemPrompt\n\nFarmer Question: $question';
    debugPrint('OfflineAI: Sending to Ollama — "$question"');

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _ollamaModel,
              'prompt': prompt,
              'stream': false,
              'options': {
                'num_predict': 150, // limit tokens for speed
                'temperature': 0.4,
              },
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Ollama timed out after 30s'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['response']?.toString().trim() ?? '';
        if (text.isEmpty) throw Exception('Ollama returned empty response');
        debugPrint('OfflineAI: Got answer from Ollama.');
        return text;
      } else {
        throw Exception('Ollama HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('OfflineAI: Error — $e');
      rethrow;
    }
  }

  /// Streaming version — Ollama supports SSE streams but we simulate
  /// chunked output by yielding the full answer at once for consistency.
  Stream<String> streamAnswer(String question) async* {
    final answer = await getAnswer(question);
    yield answer;
  }
}

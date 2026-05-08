import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class OnlineAiService {
  GenerativeModel? _model;

  OnlineAiService() {
    _initModel();
  }

  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            maxOutputTokens: 150,
            temperature: 0.3,
          ),
          systemInstruction: Content.system(
            'You are a concise agricultural AI assistant for Indian farmers. '
            'Always answer in 1-3 short sentences using simple language. '
            'Never use bullet points, headers, or long explanations. '
            'Focus only on the exact question asked. '
            'If asked about crop, fertilizer, weather or irrigation give a direct practical tip.',
          ),
        );
      } catch (e) {
        debugPrint("Error initializing GenerativeModel: ${e.toString()}");
      }
    }
  }

  Future<String> askOnlineAI(String question) async {
    if (_model == null) {
      _initModel();
    }

    if (_model == null) {
      return "Error: Online AI API Key is missing or invalid.";
    }

    try {
      final response = await _model!
          .generateContent([Content.text(question)])
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Response timed out after 10 seconds.'),
          );
      return response.text?.trim() ?? "Unable to generate response.";
    } catch (e) {
      debugPrint('Online AI Exception: ${e.toString()}');
      throw Exception("Online AI unavailable.");
    }
  }
}

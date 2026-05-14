import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Handles all Gemini (online) AI communication.
/// Automatically rotates through models if one has a quota error.
class OnlineAiService {
  // Models tried in order — each has a separate quota pool
  static const List<String> _modelPriority = [
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-pro',
  ];

  static int _modelIndex = 0;
  static String get _modelName => _modelPriority[_modelIndex];

  // Singleton model — reset when rotating
  static GenerativeModel? _model;

  static bool get isAvailable {
    final key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    return key.isNotEmpty && !key.contains('your_');
  }

  static void _buildModel() {
    if (!isAvailable) return;
    final apiKey = dotenv.env['GEMINI_API_KEY']!.trim();
    try {
      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 300,
          temperature: 0.4,
        ),
        systemInstruction: Content.system(
          'You are a helpful agricultural AI assistant for Indian farmers. '
          'Give practical, clear advice in 3-5 sentences. '
          'Focus on actionable tips about crops, fertilizers, irrigation, soil health, and weather. '
          'Use simple language that farmers can understand.',
        ),
      );
      debugPrint('OnlineAI: Using model "$_modelName"');
    } catch (e) {
      debugPrint('OnlineAI: Error creating model "$_modelName": $e');
      _model = null;
    }
  }

  static void _ensureModel() {
    if (_model == null) _buildModel();
  }

  /// Rotate to next model on quota error.
  static bool _tryNextModel() {
    if (_modelIndex < _modelPriority.length - 1) {
      _modelIndex++;
      _model = null;
      debugPrint('OnlineAI: Rotating to model "${_modelPriority[_modelIndex]}"');
      _buildModel();
      return true;
    }
    debugPrint('OnlineAI: All models exhausted quota.');
    return false;
  }

  static bool _isQuotaError(Object e) {
    return e.toString().contains('quota') ||
        e.toString().contains('RESOURCE_EXHAUSTED') ||
        e.toString().contains('limit: 0');
  }

  /// Streams the Gemini response token by token.
  /// Automatically tries the next model if quota is exceeded.
  Stream<String> streamAnswer(String question) async* {
    _ensureModel();
    if (_model == null) {
      throw Exception('Gemini API key missing or invalid.');
    }

    debugPrint('OnlineAI: Streaming from $_modelName — "$question"');
    bool yielded = false;

    try {
      final stream = _model!.generateContentStream([Content.text(question)]);
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yielded = true;
          yield text;
        }
      }
    } catch (e) {
      if (_isQuotaError(e) && !yielded && _tryNextModel()) {
        // Retry with next model
        yield* streamAnswer(question);
      } else {
        debugPrint('OnlineAI: Stream error — $e');
        rethrow;
      }
    }
  }

  /// Non-streaming version.
  Future<String> getAnswer(String question) async {
    _ensureModel();
    if (_model == null) {
      throw Exception('Gemini API key missing or invalid.');
    }
    try {
      final response = await _model!
          .generateContent([Content.text(question)])
          .timeout(const Duration(seconds: 30));
      return response.text?.trim() ?? '';
    } catch (e) {
      if (_isQuotaError(e) && _tryNextModel()) {
        return getAnswer(question);
      }
      rethrow;
    }
  }
}

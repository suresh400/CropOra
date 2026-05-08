import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OfflineAiService {
  String get _baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:11434/api/generate';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:11434/api/generate';
    return 'http://127.0.0.1:11434/api/generate';
  }

  Future<String> askOfflineAI(String question) async {
    const systemPrompt = '''
You are an agriculture expert helping farmers.
Provide advice about:
- crop diseases
- fertilizer usage
- irrigation
- pest control
- soil health
Answer in simple language for farmers.
''';

    final fullPrompt = "$systemPrompt\n\nUser Question: $question";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "phi3",
          "prompt": fullPrompt,
          "stream": false
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? "I couldn't process that request offline.";
      } else {
        throw Exception("Offline API returned \${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Offline AI Exception: \$e');
      throw Exception("Connection to the local AI expert failed.");
    }
  }
}

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  // Remove load for testing locally or use testLoad properly if available.
  // We'll mimic env for this test script if needed, or assume .env is loaded.
  dotenv.env['GEMINI_API_KEY'] = 'AIzaSyBVE4znqdckFtJwXvLpqBfktVuQsJpDAYw';
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  print("API Key: \$apiKey");
  try {
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey!);
    final chatSession = model.startChat();
    print("Sending message...");
    final response = await chatSession.sendMessage(Content.text("Hello"));
    print("Response: \${response.text}");
  } catch (e) {
    print("Error: \$e");
  }
}

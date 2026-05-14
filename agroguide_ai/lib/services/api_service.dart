import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'recommendations_service.dart';
import '../features/ai_expert/services/offline_engine.dart';
import 'translation_service.dart';

class ApiService {
  static const String baseUrl = 'https://api.agroguide-example.com/v1'; // Dummy URL for now

  Future<Map<String, dynamic>> getCropRecommendation(Map<String, dynamic> data) async {
    // Simulate API delay for better UX
    await Future.delayed(const Duration(milliseconds: 800));
    return RecommendationsService.recommendCrop(data);
  }

  Future<Map<String, dynamic>> getFertilizerAdvice(Map<String, dynamic> data) async {
    // Simulate API delay for better UX
    await Future.delayed(const Duration(milliseconds: 800));
    return RecommendationsService.recommendFertilizer(data);
  }

  Future<Map<String, dynamic>> detectPest(String imagePath) async {
    // In a real scenario, use MultipartRequest for image upload
    return _postRequest('/detect-pest', {'image_path': imagePath});
  }

  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_openweather_api_key_here') {
      return _getSimulatedResponse('/weather');
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sunrise = data['sys']?['sunrise'] ?? 0;
        final sunset = data['sys']?['sunset'] ?? 0;
        return {
          'temperature': data['main']['temp'].round(),
          'feels_like': data['main']['feels_like'].round(),
          'temp_min': data['main']['temp_min'].round(),
          'temp_max': data['main']['temp_max'].round(),
          'condition': data['weather'][0]['main'],
          'description': data['weather'][0]['description'],
          'icon': data['weather'][0]['icon'],
          'humidity': data['main']['humidity'],
          'pressure': data['main']['pressure'],
          'visibility': (data['visibility'] ?? 10000) ~/ 1000,
          'wind_speed': data['wind']['speed'],
          'wind_deg': data['wind']['deg'] ?? 0,
          'clouds': data['clouds']['all'],
          'city': data['name'],
          'country': data['sys']?['country'] ?? '',
          'sunrise': sunrise,
          'sunset': sunset,
          'lat': lat,
          'lon': lon,
        };
      } else {
        return _getSimulatedResponse('/weather');
      }
    } catch (e) {
      return _getSimulatedResponse('/weather');
    }
  }

  Future<String> chatWithExpert(String message, {bool offlineModeFallback = false, String targetLang = 'en'}) async {
    // 1. Connectivity & Settings Check
    final connectivityResult = await Connectivity().checkConnectivity();
    
    bool hasInternet = true;
    if (connectivityResult is List) {
      final list = connectivityResult as List;
      hasInternet = list.isNotEmpty && !list.every((e) => e.toString() == 'ConnectivityResult.none');
    } else {
      hasInternet = connectivityResult.toString() != 'ConnectivityResult.none';
    }

    // 2. Offline Mode Logic
    if (offlineModeFallback || !hasInternet) {
      final offlineResponse = await OfflineEngine.getResponse(message);
      return TranslationService.translateDynamic(offlineResponse, targetLang);
    }

    // 3. Online Gemini Logic
    final geminiKey = dotenv.env['GEMINI_API_KEY']?.trim();
    final openAiKey = dotenv.env['OPENAI_API_KEY']?.trim();
    final apiKey = (geminiKey != null && geminiKey.isNotEmpty) ? geminiKey : openAiKey;

    if (apiKey == null || apiKey.isEmpty || apiKey.contains('your_')) {
       // Fallback to offline if online is requested but API key is missing
       final offlineFallbackResponse = await OfflineEngine.getResponse(message);
       return TranslationService.translateDynamic(offlineFallbackResponse, targetLang);
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final content = [Content.text('You are an agricultural expert providing advice to farmers. Keep it helpful and concise. Query: $message')];
      final response = await model.generateContent(content).timeout(const Duration(seconds: 20));
      
      if (response.text == null || response.text!.isEmpty) {
        return await TranslationService.translateDynamic("The AI expert returned an empty response.", targetLang);
      }
      
      return await TranslationService.translateDynamic(response.text!, targetLang);
    } catch (e) {
      debugPrint('Gemini Error: $e');
      String errorMsg = e.toString();
      
      if (errorMsg.contains('CORS') || errorMsg.contains('XMLHttpRequest') || errorMsg.contains('403') || errorMsg.contains('Invalid API key')) {
         // Fallback to offline on fatal API errors
         debugPrint('Falling back to OfflineEngine due to API Error.');
         final offlineFallbackResponse = await OfflineEngine.getResponse(message);
         return TranslationService.translateDynamic(offlineFallbackResponse, targetLang);
      }

      return await TranslationService.translateDynamic("Failed to connect to AI Expert. Details: $errorMsg", targetLang);
    }
  }

  Future<Map<String, dynamic>> _postRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data: \${response.statusCode}');
      }
    } catch (e) {
      // Return a simulated response for UI showcase
      return _getSimulatedResponse(endpoint);
    }
  }

  Future<Map<String, dynamic>> _getRequest(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data: \${response.statusCode}');
      }
    } catch (e) {
      return _getSimulatedResponse(endpoint);
    }
  }

  // Simulated responses for the UI since we don't have a real backend
  Map<String, dynamic> _getSimulatedResponse(String endpoint) {
    if (endpoint.contains('/detect-pest')) {
      return {
        'detected_pest': 'Brown Plant Hopper',
        'severity': 'Medium',
        'treatment': 'Apply Imidacloprid spray.'
      };
    } else if (endpoint.contains('/weather')) {
      final now = DateTime.now();
      return {
        'temperature': 28,
        'feels_like': 31,
        'temp_min': 24,
        'temp_max': 32,
        'condition': 'Partly Cloudy',
        'description': 'partly cloudy with warm breeze',
        'icon': '02d',
        'humidity': 65,
        'pressure': 1012,
        'visibility': 10,
        'wind_speed': 4.5,
        'wind_deg': 220,
        'clouds': 40,
        'city': 'My Farm',
        'country': 'IN',
        'sunrise': now.copyWith(hour: 6, minute: 12, second: 0).millisecondsSinceEpoch ~/ 1000,
        'sunset': now.copyWith(hour: 18, minute: 45, second: 0).millisecondsSinceEpoch ~/ 1000,
        'lat': 0.0,
        'lon': 0.0,
      };
    }
    return {};
  }
}

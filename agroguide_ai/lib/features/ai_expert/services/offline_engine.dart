import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../../../services/database_service.dart';

class OfflineEngine {
  static Map<String, dynamic>? _knowledgeBase;

  static Future<void> _loadDataset() async {
    if (_knowledgeBase != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/agriculture_knowledge.json');
      _knowledgeBase = jsonDecode(jsonString);
    } catch (e) {
      debugPrint("Error loading offline knowledge base: \$e");
      _knowledgeBase = {};
    }
  }

  static Future<String> getResponse(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    
    // 1. Check local chat history first
    try {
      final dbService = DatabaseService();
      final chats = await dbService.getChatHistory();
      
      String? dbMatchResponse;
      int dbHighestScore = 0;
      
      final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      
      for (int i = 0; i < chats.length - 1; i++) {
        final chat = chats[i];
        if (chat['is_user'] == 1) {
          final prevQuery = chat['message'].toString().toLowerCase().trim();
          int score = 0;
          
          if (prevQuery == lowerQuery) {
            score = 100; // Exact match
          } else {
             for (var word in queryWords) {
               if (prevQuery.contains(word)) score += 2;
             }
          }
          
          // Threshold to consider it a reasonable match
          int threshold = queryWords.isEmpty ? 100 : (queryWords.length); 
          if (score > dbHighestScore && score >= threshold) {
             dbHighestScore = score;
             // Ensure the next message is from the AI and within a reasonable timeframe (or just next in list)
             final nextChat = chats[i + 1];
             if (nextChat['is_user'] == 0) {
               dbMatchResponse = nextChat['message'].toString();
             }
          }
        }
      }
      
      if (dbMatchResponse != null) {
        // Strip previous prefixes to avoid stacking [Offline] tags
        var cleanedResponse = dbMatchResponse.replaceAll(RegExp(r'^\[.*?\]\n\n'), '');
        return "[Offline: Found in History]\n\n$cleanedResponse";
      }
    } catch (e) {
      debugPrint('Error searching DB for offline response: $e');
    }

    // 2. Fallback to local JSON dataset
    await _loadDataset();
    
    // Simple keyword matching logic
    String bestMatchKey = "fallback";
    int highestScore = 0;

    _knowledgeBase?.forEach((key, value) {
      if (key == 'fallback') return;
      
      int score = 0;
      final titleWords = value['title'].toString().toLowerCase().split(' ');
      final causeWords = value['cause'].toString().toLowerCase().split(' ');
      
      for (var word in lowerQuery.split(RegExp(r'\s+'))) {
        if (word.length > 3) { // Ignore short common words
          if (key.contains(word)) score += 3;
          for (var tWord in titleWords) {
             if (tWord.contains(word) || word.contains(tWord)) score += 2;
          }
           for (var cWord in causeWords) {
             if (cWord.contains(word) || word.contains(cWord)) score += 1;
          }
        }
      }

      if (score > highestScore) {
        highestScore = score;
        bestMatchKey = key;
      }
    });

    final match = _knowledgeBase?[bestMatchKey] ?? _knowledgeBase?['fallback'];
    
    return "[Offline Mode]\\n**\${match['title']}**\\n\\n*Cause:* \${match['cause']}\\n*Advice:* \${match['solution']}";
  }
}

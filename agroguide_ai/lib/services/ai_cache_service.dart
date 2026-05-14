import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Stop words that carry no agricultural meaning and should NOT contribute to
/// cache similarity scoring (avoids false positive matches).
const _stopWords = {
  'how', 'what', 'when', 'where', 'why', 'which', 'who', 'is', 'are', 'was',
  'the', 'a', 'an', 'in', 'on', 'at', 'to', 'for', 'of', 'and', 'or', 'but',
  'it', 'its', 'me', 'my', 'you', 'your', 'we', 'our', 'they', 'their',
  'this', 'that', 'these', 'those', 'be', 'been', 'being', 'have', 'has',
  'had', 'do', 'does', 'did', 'will', 'would', 'can', 'could', 'should',
  'may', 'might', 'shall', 'tell', 'give', 'need', 'want', 'know',
  'take', 'takes', 'taken', 'many', 'much', 'more', 'most', 'some', 'any',
  'long', 'time', 'days', 'weeks', 'months', 'years', 'about', 'from',
  'with', 'into', 'through', 'during', 'before', 'after', 'above', 'below',
  'between', 'out', 'off', 'over', 'under', 'again', 'then', 'once',
  'grow', 'growing', 'cultivate', 'cultivation', 'plant', 'planting',
  'crop', 'crops', 'farm', 'farmer', 'farming', 'agriculture',
};

/// Minimum number of meaningful content words that must match for a cache hit.
const _minContentWordMatches = 2;

List<String> _contentWords(String sentence) {
  return sentence
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toList();
}

/// Stores AI question-answer pairs and retrieves similar ones for fast responses.
class AiCacheService {
  /// Look up a cached answer for [question].
  /// Returns null if no sufficiently similar cached question is found.
  static Future<String?> getCachedAnswer(String question) async {
    try {
      final db = await DatabaseService().database;
      final rows = await db.query(
        'ai_cache',
        orderBy: 'used_count DESC, timestamp DESC',
        limit: 300,
      );

      if (rows.isEmpty) return null;

      final lowerQ = question.toLowerCase().trim();
      final qContentWords = _contentWords(lowerQ);

      String? bestAnswer;
      int bestId = -1;
      int bestMatches = 0;

      for (final row in rows) {
        final cachedQ = row['question'].toString().toLowerCase().trim();

        // Exact match — return immediately
        if (cachedQ == lowerQ) {
          _incrementUsage(row['id'] as int);
          debugPrint('AI Cache: ✅ Exact hit for "$question"');
          return row['answer'].toString();
        }

        // Count matching *content* words only (no stop words)
        final cachedContentWords = _contentWords(cachedQ);
        int matches = 0;
        for (final word in qContentWords) {
          if (cachedContentWords.contains(word)) matches++;
        }

        // Only consider a match if BOTH questions share enough content words
        // AND at least half of the query's content words match
        final halfThreshold = (qContentWords.length / 2).ceil();
        if (matches >= _minContentWordMatches &&
            matches >= halfThreshold &&
            matches > bestMatches) {
          bestMatches = matches;
          bestAnswer = row['answer'].toString();
          bestId = row['id'] as int;
        }
      }

      if (bestAnswer != null && bestId > 0) {
        debugPrint(
            'AI Cache: ✅ Fuzzy hit ($bestMatches content-word matches) for "$question"');
        _incrementUsage(bestId);
        return bestAnswer;
      }

      debugPrint('AI Cache: ❌ No cache hit for "$question"');
      return null;
    } catch (e) {
      debugPrint('AI Cache lookup error: $e');
      return null;
    }
  }

  /// Save a question-answer pair to the cache.
  static Future<void> saveToCache(
      String question, String answer, String source) async {
    if (question.trim().isEmpty || answer.trim().isEmpty) return;
    try {
      final db = await DatabaseService().database;
      await db.insert(
        'ai_cache',
        {
          'question': question.trim().toLowerCase(),
          'answer': answer.trim(),
          'source': source,
          'timestamp': DateTime.now().toIso8601String(),
          'used_count': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('AI Cache: 💾 Saved Q&A from $source — "$question"');
    } catch (e) {
      debugPrint('AI Cache save error: $e');
    }
  }

  static void _incrementUsage(int id) async {
    try {
      final db = await DatabaseService().database;
      await db.rawUpdate(
          'UPDATE ai_cache SET used_count = used_count + 1 WHERE id = ?',
          [id]);
    } catch (_) {}
  }
}

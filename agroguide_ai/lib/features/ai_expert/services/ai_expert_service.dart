import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../../../providers/settings_provider.dart';
import '../../../services/online_ai_service.dart';
import '../../../services/offline_ai_service.dart';
import '../../../services/network_service.dart';
import '../../../services/ai_cache_service.dart';
import '../../ai_expert/services/offline_engine.dart';

/// Orchestrates the AI pipeline:
/// 1. Check DB cache (instant response for repeated/similar questions)
/// 2. Online → Gemini (streaming)
/// 3. Offline → Ollama (local model)
/// 4. Fallback → OfflineEngine (JSON knowledge base)
class AiExpertService extends ChangeNotifier {
  final OnlineAiService _onlineAi = OnlineAiService();
  final OfflineAiService _offlineAi = OfflineAiService();

  // Cache network check for 60 seconds
  bool? _cachedHasInternet;
  DateTime? _cacheTime;

  Future<bool> _hasInternet() async {
    final now = DateTime.now();
    if (_cachedHasInternet != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!).inSeconds < 60) {
      return _cachedHasInternet!;
    }
    final result = await NetworkService().hasInternet();
    _cachedHasInternet = result;
    _cacheTime = now;
    debugPrint('AiExpert: Internet check → $result');
    return result;
  }

  /// Primary method — streams the response for instant display.
  /// Saves answer to DB cache after completion.
  Stream<String> askExpertStream(BuildContext context, String question) async* {
    final offlineMode =
        Provider.of<SettingsProvider>(context, listen: false).offlineMode;

    // ── Step 1: Check DB cache ──────────────────────────────────────────
    final cached = await AiCacheService.getCachedAnswer(question);
    if (cached != null) {
      debugPrint('AiExpert: Serving from cache ⚡');
      yield '[From Cache] $cached';
      return;
    }

    // ── Step 2A: Offline mode → Ollama → OfflineEngine ─────────────────
    if (offlineMode) {
      debugPrint('AiExpert: Offline mode → trying Ollama');
      yield* _tryOllamaThenFallback(question);
      return;
    }

    // ── Step 2B: Online mode → Gemini → Ollama → OfflineEngine ─────────
    final internet = await _hasInternet();

    if (internet && OnlineAiService.isAvailable) {
      debugPrint('AiExpert: Online → Gemini');
      final buffer = StringBuffer();
      try {
        await for (final chunk in _onlineAi.streamAnswer(question)) {
          buffer.write(chunk);
          yield chunk;
        }
        // Save successful Gemini answer to cache
        if (buffer.isNotEmpty) {
          AiCacheService.saveToCache(question, buffer.toString(), 'gemini');
        }
        return;
      } catch (e) {
        debugPrint('AiExpert: Gemini failed ($e) → trying Ollama');
        // If Gemini fails, fall through to Ollama
      }
    }

    // ── Step 3: Ollama or OfflineEngine ────────────────────────────────
    yield* _tryOllamaThenFallback(question);
  }

  /// Tries Ollama first, falls back to OfflineEngine (JSON knowledge base).
  Stream<String> _tryOllamaThenFallback(String question) async* {
    try {
      final ollamaRunning = await OfflineAiService.isOllamaRunning();
      if (ollamaRunning) {
        debugPrint('AiExpert: Ollama is running → sending request');
        final answer = await _offlineAi.getAnswer(question);
        yield answer;
        AiCacheService.saveToCache(question, answer, 'ollama');
        return;
      } else {
        debugPrint('AiExpert: Ollama not running → OfflineEngine');
      }
    } catch (e) {
      debugPrint('AiExpert: Ollama failed ($e) → OfflineEngine');
    }

    // Final fallback — JSON knowledge base
    final answer = await OfflineEngine.getResponse(question);
    yield answer;
    AiCacheService.saveToCache(question, answer, 'offline_engine');
  }
}

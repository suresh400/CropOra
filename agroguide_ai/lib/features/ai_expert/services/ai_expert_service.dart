import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../../../providers/settings_provider.dart';
import '../../../services/online_ai_service.dart';
import '../../../services/offline_ai_service.dart';
import '../../../services/network_service.dart';

class AiExpertService extends ChangeNotifier {
  final OnlineAiService _onlineAi = OnlineAiService();
  final OfflineAiService _offlineAi = OfflineAiService();

  // Cache network result for 30 seconds to avoid repeated checks
  bool? _cachedHasInternet;
  DateTime? _cacheTime;

  Future<bool> _hasInternet() async {
    final now = DateTime.now();
    if (_cachedHasInternet != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!).inSeconds < 30) {
      return _cachedHasInternet!;
    }
    final result = await NetworkService().hasInternet();
    _cachedHasInternet = result;
    _cacheTime = now;
    return result;
  }

  Future<String> askExpert(BuildContext context, String question) async {
    final offlineMode =
        Provider.of<SettingsProvider>(context, listen: false).offlineMode;

    debugPrint("Hybrid AI Init - Offline Mode: $offlineMode");

    if (offlineMode) {
      debugPrint("Hybrid AI: Routing via Offline Model (Settings Override)");
      return await _offlineAi.askOfflineAI(question);
    }

    // Use cached connectivity check — much faster on repeated messages
    final internet = await _hasInternet();

    if (internet) {
      try {
        debugPrint("Hybrid AI: Routing via Gemini (Online)");
        return await _onlineAi.askOnlineAI(question);
      } catch (e) {
        debugPrint("Hybrid AI: Gemini failed, falling back. Error: $e");
        return await _offlineAi.askOfflineAI(question);
      }
    }

    debugPrint("Hybrid AI: No internet, routing via Offline Model");
    return await _offlineAi.askOfflineAI(question);
  }
}

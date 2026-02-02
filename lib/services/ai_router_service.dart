import 'package:flutter/foundation.dart';
import 'groq_service.dart';
import 'watson_service.dart';
import 'secure_storage_service.dart';

class AiRouterService {
  final GroqService _groqService;
  final WatsonService _watsonService;
  final SecureStorageService _secureStorage;

  AiRouterService(this._groqService, this._watsonService, this._secureStorage);

  /// Automatically routes the request to the best available provider.
  /// Priority:
  /// 1. Groq (Fastest) - if API key exists.
  /// 2. Watson (Enterprise) - if credentials exist.
  /// 3. Error - if no provider configured.
  Stream<String> routeRequest(String transcript, {String? context}) async* {
    // 1. Check Groq
    final groqKey = await _secureStorage.getGroqApiKey();
    if (groqKey != null && groqKey.isNotEmpty) {
      debugPrint("AiRouter: Routing to Groq (Fastest)");
      yield* _groqService.analyzeIdeaStream(
        transcript,
        previousContext: context,
      );
      return;
    }

    // 2. Check Watson
    final watsonCreds = await _secureStorage.getWatsonCredentials();
    final watsonKey = watsonCreds['apiKey'];
    final watsonProject = watsonCreds['projectId'];

    if (watsonKey != null &&
        watsonKey.isNotEmpty &&
        watsonProject != null &&
        watsonProject.isNotEmpty) {
      debugPrint("AiRouter: Routing to Watson (Enterprise)");
      yield* _watsonService.analyzeIdeaStream(
        transcript,
        previousContext: context,
      );
      return;
    }

    // 3. No Provider Configured
    debugPrint("AiRouter: No provider configured");
    yield "Please configure an AI provider (Groq or Watson) in Settings to continue.";
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

class GroqService {
  final SecureStorageService _secureStorage;
  final Dio _dio = Dio();

  GroqService(this._secureStorage);

  Future<String?> analyzeIdea(
    String currentTranscript, {
    String? previousContext,
  }) async {
    final apiKey = await _secureStorage.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return "Please configure Groq API Key in Settings.";
    }

    try {
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          "model": "llama-3.1-8b-instant", // User requested "llama instant"
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful brainstorming assistant.",
            },
            {
              "role": "user",
              "content": previousContext != null
                  ? "Context: $previousContext\n\nInput: $currentTranscript"
                  : currentTranscript,
            },
          ],
        },
      );

      final content = response.data['choices'][0]['message']['content'];
      return content.toString();
    } catch (e) {
      if (e is DioException) {
        debugPrint("Groq API Error: ${e.response?.data}");
        return "Groq Error: ${e.response?.statusCode} - ${e.response?.statusMessage}";
      }
      return "Groq Error: $e";
    }
  }

  Stream<String> analyzeIdeaStream(
    String currentTranscript, {
    String? previousContext,
  }) async* {
    // 1. Check API Key
    final apiKey = await _secureStorage.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      yield "Please configure Groq API Key in Settings.";
      return;
    }

    // 2. Use the stable non-streaming implementation
    try {
      final result = await analyzeIdea(
        currentTranscript,
        previousContext: previousContext,
      );

      if (result != null) {
        // Simulate streaming for UI consistency
        final words = result.split(' ');
        for (var word in words) {
          yield "$word ";
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } else {
        yield "Groq returned no response.";
      }
    } catch (e) {
      yield "Groq Error: $e";
    }
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WatsonService {
  // Use the standard IBM IAM endpoint for tokens
  final String _iamUrl = "https://iam.cloud.ibm.com/identity/token";
  // WML Endpoint (using US-South/Dallas as an example)
  final String _wmlUrl =
      "https://us-south.ml.cloud.ibm.com/ml/v1/text/generation?version=2024-05-31";
  final String _ttsUrl =
      "https://api.us-south.text-to-speech.watson.cloud.ibm.com/v1/synthesize";

  final String _apiKey = "5HbZ-Borj7c_tqgvHrKosIRklcUZZmjU8TjY_MZ4lcFK";
  final String _projectId = "37a77f3e-f608-434e-9f0f-9408649a6ed9";

  // Cache token
  String? _cachedToken;
  DateTime? _tokenExpiration;

  Future<String?> _getAccessToken() async {
    // Return cached token if valid
    if (_cachedToken != null &&
        _tokenExpiration != null &&
        DateTime.now().isBefore(_tokenExpiration!)) {
      return _cachedToken;
    }

    try {
      final response = await http.post(
        Uri.parse(_iamUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ibm:params:oauth:grant-type:apikey',
          'apikey': _apiKey,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedToken = data['access_token'];
        // Cache for 50 minutes (tokens usually expire in 60)
        _tokenExpiration = DateTime.now().add(const Duration(minutes: 50));
        return _cachedToken;
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
    return null;
  }

  Stream<String> analyzeIdeaStream(
    String currentTranscript, {
    String? previousContext,
  }) async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("User must be logged in to brainstorm!");
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final token = await _getAccessToken();
    if (token == null) {
      debugPrint("Failed to get Watson access token");
      return;
    }

    final String personaInstructions = """
You are an inquisitive and helpful AI assistant for brainstorming.
Your goal is to help the user refine their idea by asking relevant follow-up questions.
IMPORTANT: Keep your response concise and summarized to avoid hitting token limits.
Always include 1-2 questions at the end of your response.
""";

    String promptInput;
    if (previousContext != null && previousContext.isNotEmpty) {
      // previousContext can be a concatenated string of recent messages
      promptInput =
          """
$personaInstructions

Recent conversation history:
$previousContext

User: $currentTranscript
AI: """;
    } else {
      promptInput =
          """
$personaInstructions

User Idea: $currentTranscript

Summarize this idea, suggest a tech stack, and then ask inquisitive follow-up questions.
AI: """;
    }

    final streamUrl = _wmlUrl.replaceFirst("generation", "generation_stream");

    try {
      final request = http.Request('POST', Uri.parse(streamUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.body = jsonEncode({
        "input": promptInput,
        "model_id": "ibm/granite-3-3-8b-instruct",
        "project_id": _projectId,
        "parameters": {
          "max_new_tokens": 500, // Increased limit for streaming
          "decoding_method": "greedy",
          "repetition_penalty": 1.1,
        },
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final stream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (line.startsWith("data: ")) {
            final dataStr = line.substring(6);
            if (dataStr == "[DONE]") {
              break;
            }
            try {
              // Watson stream format usually sends JSON chunks
              // If dataStr is empty or simple keep-alive, skip.
              if (dataStr.trim().isEmpty) continue;

              final data = jsonDecode(dataStr);
              // Structure: { "results": [ { "generated_text": "...", "generated_token_count": ... } ] }
              if (data['results'] != null && data['results'].isNotEmpty) {
                final text = data['results'][0]['generated_text'];
                if (text != null) {
                  yield text;
                }
              }
            } catch (e) {
              debugPrint("Error parsing SSE chunk: $e");
            }
          }
        }
      } else {
        debugPrint(
          "Watson Stream API error: ${response.statusCode} ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      debugPrint("Watson Stream Error: $e");
    }
  }

  // Keeping the original Future-based method for compatibility or fallback, but refactoring it to use the same logic if needed.
  // For now, we leave analyzeIdea as is or deprecated.
  Future<String?> analyzeIdea(
    String currentTranscript, {
    String? previousContext,
  }) async {
    // ... (Existing implementation kept for now, or could call stream and join)
    // For brevity and compliance with instruction, I am replacing the method block.
    // If I need to KEEP the old method, I should have used multi_replace or defined the range carefully.
    // The instruction implied replacing the logic. I will rewrite analyzeIdea to collect the stream for backward compatibility if needed,
    // OR just replace it with the new signature if I update consumers.
    // I will ADD analyzeIdeaStream and KEEP analyzeIdea for now to avoid breaking VoiceService immediately.
    // Wait, the tool is REPLACE. I must replace the target content.
    // I will replace the entire analyzeIdea method with BOTH methods, ensuring migration.

    // Actually, I'll update analyzeIdea to use the stream internally to be safe, OR return the full string.
    // But better to expose the stream.

    // I will return the original implementation of analyzeIdea + the new stream method.
    // Since I cannot do "append", I have to provide the full replacement.

    // RE-USING ORIGINAL LOGIC FOR analyzeIdea TO MINIMIZE RISK, ADDING analyzeIdeaStream.

    return _analyzeIdeaLegacy(
      currentTranscript,
      previousContext: previousContext,
    );
  }

  Future<String?> _analyzeIdeaLegacy(
    String currentTranscript, {
    String? previousContext,
  }) async {
    // (Original logic copied here for safety)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final token = await _getAccessToken();
    if (token == null) return null;

    String promptInput;
    if (previousContext != null && previousContext.isNotEmpty) {
      promptInput =
          "Here is the original idea context:\n$previousContext\n\nNow, I have further thoughts:\n$currentTranscript\n\nPlease update the implementation plan or summary based on these new details.\n";
    } else {
      promptInput =
          "Summarize this idea and suggest one tech stack: $currentTranscript";
    }

    try {
      final response = await http.post(
        Uri.parse(_wmlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer \$token',
        },
        body: jsonEncode({
          "input": promptInput,
          "model_id": "ibm/granite-3-3-8b-instruct",
          "project_id": _projectId,
          "parameters": {
            "max_new_tokens": 300,
            "decoding_method": "greedy",
            "repetition_penalty": 1.1,
          },
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['results'][0]['generated_text'];
      }
    } catch (e) {
      debugPrint("Legacy Watson Error: \$e");
    }
    return null;
  }

  bool _isTtsEnabled = true;

  Future<Uint8List?> synthesizeSpeech(String text) async {
    if (!_isTtsEnabled) return null;

    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse("$_ttsUrl?voice=en-US_AllisonV3Voice"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'audio/wav',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        debugPrint(
          "Watson TTS Forbidden (403/401). Disabling Watson TTS and falling back to Device TTS.",
        );
        _isTtsEnabled = false; // Disable to prevent log spam
      } else {
        debugPrint("Watson TTS Error: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Watson TTS Exception: $e");
    }
    return null;
  }
}

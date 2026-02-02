import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ideaflow/src/rust/api/inference.dart';

class OfflineAiService {
  /// Checks if the necessary model files exist on the device.
  Future<bool> isModelAvailable() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelPath = "${docsDir.path}/gemma-2b-it-q4_k_m.gguf";
    final tokenizerPath = "${docsDir.path}/tokenizer.json";

    return File(modelPath).existsSync() && File(tokenizerPath).existsSync();
  }

  /// Starts the offline brainstorming session by calling Rust.
  /// Returns a Stream of tokens.
  Future<Stream<String>> startBrainstorming(String prompt) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelPath = "${docsDir.path}/gemma-2b-it-q4_k_m.gguf";
    final tokenizerPath = "${docsDir.path}/tokenizer.json";

    if (!await isModelAvailable()) {
      throw Exception(
        "Offline model not found.\nPlease sideload 'gemma-2b-it-q4_k_m.gguf' and 'tokenizer.json' to:\n${docsDir.path}",
      );
    }

    return runOfflineGemma(
      prompt: prompt,
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  final _currentWordController = StreamController<String>.broadcast();
  Stream<String> get currentWordStream => _currentWordController.stream;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(1.0);

    _flutterTts.setProgressHandler((text, start, endOffset, word) {
      _currentWordController.add(word);
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Force Device TTS as per user request
    debugPrint("Using Device TTS");
    await stop(); // Stop any playing audio
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

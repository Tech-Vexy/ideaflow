import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  final _currentWordController = StreamController<TtsProgress>.broadcast();
  Stream<TtsProgress> get currentWordStream => _currentWordController.stream;

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);

    // Android and Web are often faster than iOS at default rates.
    // Setting both to 0.4 to ensure consistency.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      await _flutterTts.setSpeechRate(0.4);
    } else {
      await _flutterTts.setSpeechRate(0.5); // iOS
    }

    _flutterTts.setProgressHandler((text, start, endOffset, word) {
      _currentWordController.add(
        TtsProgress(word: word, start: start, end: endOffset),
      );
    });

    _flutterTts.setCompletionHandler(() {
      isPlaying.value = false;
    });

    _flutterTts.setCancelHandler(() {
      isPlaying.value = false;
    });

    _flutterTts.setPauseHandler(() {
      isPlaying.value = false;
    });

    _flutterTts.setContinueHandler(() {
      isPlaying.value = true;
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Force Device TTS as per user request
    debugPrint("Using Device TTS");
    await stop(); // Stop any playing audio
    isPlaying.value = true;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    isPlaying.value = false;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    isPlaying.value = false;
  }
}

class TtsProgress {
  final String word;
  final int start;
  final int end;
  TtsProgress({required this.word, required this.start, required this.end});
}

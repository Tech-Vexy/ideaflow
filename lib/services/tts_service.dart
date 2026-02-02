import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'watson_service.dart';

class TtsService {
  final WatsonService _watsonService;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  TtsService(this._watsonService) {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _audioPlayer.setLoopMode(LoopMode.off);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // 1. Check Connectivity
    final connectivity = await Connectivity().checkConnectivity();
    bool isOnline = !connectivity.contains(ConnectivityResult.none);

    // 2. Try Watson TTS if online
    if (isOnline) {
      try {
        final audioBytes = await _watsonService.synthesizeSpeech(text);
        if (audioBytes != null) {
          // Play audio bytes
          await _playAudioBytes(audioBytes);
          return;
        }
      } catch (e) {
        debugPrint("Watson TTS failed, falling back to device TTS: $e");
      }
    }

    // 3. Fallback to Device TTS
    debugPrint("Using Device TTS");
    await stop(); // Stop any playing audio
    await _flutterTts.speak(text);
  }

  Future<void> _playAudioBytes(Uint8List bytes) async {
    try {
      await stop(); // Stop current

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_audio.wav');
      await file.writeAsBytes(bytes);

      // Play
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Audio Player Error: $e");
      // Fallback if player fails
      await _flutterTts.speak("I have an answer but cannot play the audio.");
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
  }
}

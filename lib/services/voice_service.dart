import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInit = false;
  bool _isRecording = false;
  String _currentTranscript = "";

  bool get isRecording => _isRecording;
  String get currentTranscript => _currentTranscript;

  Future<bool> init() async {
    if (_isInit) return true;
    try {
      _isInit = await _speechToText.initialize(
        onError: (error) => debugPrint('STT Error: $error'),
        onStatus: (status) => debugPrint('STT Status: $status'),
      );
      return _isInit;
    } catch (e) {
      debugPrint('STT Init Exception: $e');
      return false;
    }
  }

  Future<void> startRecording({required Function(String) onTextUpdate}) async {
    final hasPermission = await _speechToText.hasPermission;
    if (!hasPermission) {
      final initialized = await init();
      if (!initialized) return;
    }

    if (_speechToText.isAvailable && !_speechToText.isListening) {
      _currentTranscript = "";
      _isRecording = true;
      await _speechToText.listen(
        onResult: (result) {
          _currentTranscript = result.recognizedWords;
          onTextUpdate(_currentTranscript);
          if (result.finalResult) {
            _isRecording = false;
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    }
  }

  Future<void> stopRecording() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _isRecording = false;
  }

  Future<void> cancelRecording() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    _isRecording = false;
    _currentTranscript = "";
  }
}

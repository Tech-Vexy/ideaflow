import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/voice_service.dart';
import 'services/watson_service.dart';
import 'services/offline_ai_service.dart';
import 'services/auth_service.dart';
import 'services/tts_service.dart';
import 'services/hive_service.dart';
import 'services/firebase_service.dart';
import 'services/sync_service.dart';
import 'services/secure_storage_service.dart';
import 'services/groq_service.dart';
import 'services/ai_router_service.dart';
import 'models/models.dart';

// Secure Storage Provider
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Watson Service Provider
final watsonServiceProvider = Provider<WatsonService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return WatsonService(secureStorage);
});

// Sync Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final firebase = ref.watch(firebaseServiceProvider);
  final hive = ref.watch(hiveServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return SyncService(firebase, hive, secureStorage);
});

// Groq Service Provider
final groqServiceProvider = Provider<GroqService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return GroqService(secureStorage);
});

// AI Router Service Provider
final aiRouterServiceProvider = Provider<AiRouterService>((ref) {
  final groq = ref.watch(groqServiceProvider);
  final watson = ref.watch(watsonServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AiRouterService(groq, watson, secureStorage);
});

// Firebase Service Provider
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// Offline AI Service Provider
final offlineAiServiceProvider = Provider<OfflineAiService>((ref) {
  return OfflineAiService();
});

// Voice Service Provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService();
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// TTS Service Provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

// Hive Service Provider (initialized in main.dart)
final hiveServiceProvider = Provider<HiveService>(
  (ref) => throw UnimplementedError(),
);

// Stream of Ideas from Hive
final streamIdeasProvider = StreamProvider<List<Idea>>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return hiveService.watchIdeas();
});

// Stream of Sessions for a specific Idea
final ideaSessionsProvider =
    StreamProvider.family<List<BrainstormSession>, String>((ref, ideaId) {
      final hiveService = ref.watch(hiveServiceProvider);
      return hiveService.watchSessionsForIdea(ideaId);
    });

// Search Query Logic
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// All Sessions Provider (for efficient searching)
final allSessionsProvider = StreamProvider<List<BrainstormSession>>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return hiveService.watchAllSessions();
});

// Filtered Ideas Provider
final filteredIdeasProvider = Provider<List<Idea>>((ref) {
  final ideasAsync = ref.watch(streamIdeasProvider);
  final sessionsAsync = ref.watch(allSessionsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();

  // If data isn't loaded yet, return empty list
  if (!ideasAsync.hasValue || !sessionsAsync.hasValue) {
    return [];
  }

  final allIdeas = ideasAsync.value!;

  if (query.isEmpty) {
    return allIdeas;
  }

  final allSessions = sessionsAsync.value!;

  return allIdeas.where((idea) {
    // 1. Match Title
    if (idea.title.toLowerCase().contains(query)) {
      return true;
    }

    // 2. Match Content (Transcripts/AI Insights)
    // Find sessions belonging to this idea
    final ideaSessions = allSessions.where((s) => s.ideaId == idea.id).toList();

    // Check if any session matches
    return ideaSessions.any(
      (s) =>
          s.rawTranscript.toLowerCase().contains(query) ||
          (s.aiInsight?.toLowerCase().contains(query) ?? false),
    );
  }).toList();
});

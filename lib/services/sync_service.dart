import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'hive_service.dart';

class SyncService {
  final FirebaseService _firebaseService;
  final HiveService _hiveService;

  SyncService(this._firebaseService, this._hiveService);

  Future<void> syncFromCloud() async {
    try {
      debugPrint("Starting cloud sync...");

      // 1. Sync Ideas
      final remoteIdeas = await _firebaseService.getIdeas();
      final localIdeas = _hiveService.getIdeas();
      final localIdeaIds = localIdeas.map((e) => e.id).toSet();

      for (final idea in remoteIdeas) {
        if (!localIdeaIds.contains(idea.id)) {
          debugPrint("Syncing new idea from cloud: ${idea.id}");
          await _hiveService.updateIdea(idea); // updateIdea handles put
        }
      }

      // 2. Sync Sessions
      final remoteSessions = await _firebaseService.getSessions();
      // HiveService doesn't have a direct 'getAllSessions' but we can check existence
      final localSessionsBox = _hiveService.sessionsBox;

      for (final session in remoteSessions) {
        if (!localSessionsBox.containsKey(session.id)) {
          debugPrint("Syncing new session from cloud: ${session.id}");
          await localSessionsBox.put(session.id, session);
        }
      }

      debugPrint("Cloud sync completed.");
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'package:uuid/uuid.dart';

class HiveService {
  static const String ideasBoxName = 'ideas';
  static const String sessionsBoxName = 'sessions';

  Box<Idea> get ideasBox => Hive.box<Idea>(ideasBoxName);
  Box<BrainstormSession> get sessionsBox =>
      Hive.box<BrainstormSession>(sessionsBoxName);

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(IdeaAdapter());
    Hive.registerAdapter(BrainstormSessionAdapter());
    Hive.registerAdapter(ArrayChatMessageAdapter());
    await Hive.openBox<Idea>(ideasBoxName);
    await Hive.openBox<BrainstormSession>(sessionsBoxName);
    await Hive.openBox<ArrayChatMessage>('messages');
  }

  // CRUD for Ideas
  List<Idea> getIdeas() {
    return ideasBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Stream<List<Idea>> watchIdeas() {
    return ideasBox.watch().map((_) => getIdeas());
  }

  Future<Idea> createIdea(String title) async {
    final id = const Uuid().v4();
    final idea = Idea(id: id, title: title, createdAt: DateTime.now());
    await ideasBox.put(id, idea);
    return idea;
  }

  Future<void> updateIdea(Idea idea) async {
    await ideasBox.put(idea.id, idea);
  }

  Future<void> deleteIdea(String id) async {
    await ideasBox.delete(id);
  }

  Future<void> saveMessage(ArrayChatMessage message) async {
    final box = Hive.box<ArrayChatMessage>('messages');
    await box.put(message.id, message);
  }

  // CRUD for Sessions
  Future<BrainstormSession> addSession(
    String ideaId,
    String transcript, {
    String? aiInsight,
  }) async {
    final id = const Uuid().v4();
    final session = BrainstormSession(
      id: id,
      ideaId: ideaId,
      rawTranscript: transcript,
      aiInsight: aiInsight,
      sessionDate: DateTime.now(),
    );
    await sessionsBox.put(id, session);
    return session;
  }

  List<BrainstormSession> getSessionsForIdea(String ideaId) {
    return sessionsBox.values.where((s) => s.ideaId == ideaId).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
  }

  Stream<List<BrainstormSession>> watchSessionsForIdea(String ideaId) {
    return sessionsBox.watch().map((_) => getSessionsForIdea(ideaId));
  }

  Stream<List<BrainstormSession>> watchAllSessions() {
    return sessionsBox.watch().map((_) => sessionsBox.values.toList());
  }
}

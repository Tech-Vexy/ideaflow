import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'package:uuid/uuid.dart';

class HiveService {
  static const String ideasBoxName = 'ideas';
  static const String sessionsBoxName = 'sessions';
  static const String settingsBoxName = 'settings';

  Box<Idea> get ideasBox => Hive.box<Idea>(ideasBoxName);
  Box<BrainstormSession> get sessionsBox =>
      Hive.box<BrainstormSession>(sessionsBoxName);
  Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(IdeaAdapter());
    Hive.registerAdapter(BrainstormSessionAdapter());
    Hive.registerAdapter(ArrayChatMessageAdapter());
    await Hive.openBox<Idea>(ideasBoxName);
    await Hive.openBox<BrainstormSession>(sessionsBoxName);
    await Hive.openBox<ArrayChatMessage>('messages');
    await Hive.openBox<dynamic>(settingsBoxName);
  }

  // Settings
  String getThemeMode() {
    return settingsBox.get('themeMode', defaultValue: 'system') as String;
  }

  Future<void> updateThemeMode(String mode) async {
    await settingsBox.put('themeMode', mode);
  }

  // CRUD for Ideas
  List<Idea> getIdeas() {
    return ideasBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Stream<List<Idea>> watchIdeas() async* {
    yield getIdeas();
    yield* ideasBox.watch().map((_) => getIdeas());
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

  List<ArrayChatMessage> getMessagesForIdea(String ideaId) {
    final box = Hive.box<ArrayChatMessage>('messages');
    return box.values.where((m) => m.ideaId == ideaId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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

  Stream<List<BrainstormSession>> watchSessionsForIdea(String ideaId) async* {
    yield getSessionsForIdea(ideaId);
    yield* sessionsBox.watch().map((_) => getSessionsForIdea(ideaId));
  }

  Stream<List<BrainstormSession>> watchAllSessions() async* {
    yield sessionsBox.values.toList();
    yield* sessionsBox.watch().map((_) => sessionsBox.values.toList());
  }
}

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart';

class FirebaseService {
  late final FirebaseDatabase _db;

  FirebaseService() {
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://ideaflow-8e13e-default-rtdb.firebaseio.com/',
    );
  }

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> saveIdea(Idea idea) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.ref('users/$uid/ideas/${idea.id}').set(idea.toJson());
  }

  Future<void> saveSession(BrainstormSession session) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.ref('users/$uid/sessions/${session.id}').set(session.toJson());
  }

  Future<List<Idea>> getIdeas() async {
    final uid = _userId;
    if (uid == null) return [];
    final snapshot = await _db.ref('users/$uid/ideas').get();
    if (!snapshot.exists) return [];

    final ideas = <Idea>[];
    for (final child in snapshot.children) {
      if (child.value != null) {
        ideas.add(Idea.fromJson(Map<String, dynamic>.from(child.value as Map)));
      }
    }
    return ideas;
  }

  Future<List<BrainstormSession>> getSessions() async {
    final uid = _userId;
    if (uid == null) return [];
    final snapshot = await _db.ref('users/$uid/sessions').get();
    if (!snapshot.exists) return [];

    final sessions = <BrainstormSession>[];
    for (final child in snapshot.children) {
      if (child.value != null) {
        sessions.add(
          BrainstormSession.fromJson(
            Map<String, dynamic>.from(child.value as Map),
          ),
        );
      }
    }
    return sessions;
  }
}

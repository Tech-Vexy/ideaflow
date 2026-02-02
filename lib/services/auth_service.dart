import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to listen to auth state changes (Reactive UI!)
  Stream<User?> get user => _auth.authStateChanges();

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    // For now, we'll let the UI library handle the providers,
    // but this scaffolding is here if we need custom logic later.
    // The firebase_ui_auth package handles the heavy lifting.
    return null;
  }

  // Simple Anonymous Login (Fastest for Hackathons) - Keeping for dev backup if needed
  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      debugPrint("Auth Error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

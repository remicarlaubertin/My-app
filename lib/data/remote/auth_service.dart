import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

/// Authentification Supabase (courriel + mot de passe).
///
/// Si l'application a été compilée sans clés Supabase, toutes les méthodes
/// échouent proprement : l'application reste utilisable hors ligne.
class AuthService {
  const AuthService();

  bool get available => AppConfig.cloudEnabled;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => available ? _client.auth.currentUser : null;

  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get onAuthChange => available
      ? _client.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  Future<String?> signIn(String email, String password) async {
    if (!available) return 'La synchronisation cloud n\'est pas configurée.';
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    } catch (_) {
      return 'Connexion impossible. Vérifie ta connexion Internet.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    if (!available) return 'La synchronisation cloud n\'est pas configurée.';
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    } catch (_) {
      return 'Création du compte impossible. Réessaie plus tard.';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!available) return 'La synchronisation cloud n\'est pas configurée.';
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    await _client.auth.signOut();
  }

  String _translate(String message) {
    final String m = message.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Courriel ou mot de passe incorrect.';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Ce courriel possède déjà un compte.';
    }
    if (m.contains('password')) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    if (m.contains('email')) {
      return 'Adresse courriel invalide.';
    }
    return message;
  }
}

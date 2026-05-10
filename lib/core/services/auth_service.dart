import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_service.dart';

/// Serviço de autenticação. Mantemos uma camada fina por cima do
/// FirebaseAuth para que o restante do app dependa apenas desta API
/// (facilita troca de provedor e testes).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Stream do estado de auth — usada como `refreshListenable` do GoRouter.
  Stream<User?> authStateChanges() {
    if (!FirebaseService.instance.isInitialized) {
      // Em modo mock, emite null imediatamente: usuário "anônimo logado".
      return Stream<User?>.value(null);
    }
    return FirebaseService.instance.auth.authStateChanges();
  }

  User? get currentUser =>
      FirebaseService.instance.isInitialized ? FirebaseService.instance.auth.currentUser : null;
}

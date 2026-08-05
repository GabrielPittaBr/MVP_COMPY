import '../entities/auth_user.dart';

/// Interface do repositório de autenticação.
///
/// Define o contrato que a camada de apresentação conhece — sem depender do
/// Firebase diretamente (Dependency Inversion Principle).
abstract interface class AuthRepository {
  /// Stream do estado de autenticação (emite null quando deslogado).
  Stream<AuthUser?> authState();

  /// Login com e-mail e senha.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cadastro manual: cria conta no FirebaseAuth + perfil no Firestore.
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  /// Login / cadastro via Google.
  ///
  /// Retorna um [AuthUser] onde [AuthUser.hasUsername] será `false` se for
  /// a primeira vez do usuário (fluxo intermediário de escolha de username).
  Future<AuthUser> signInWithGoogle();

  /// Verifica se o [username] ainda está disponível no Firestore.
  Future<bool> isUsernameAvailable(String username);

  /// Grava o username escolhido (fluxo pós-Google para novos usuários).
  /// Cria/atualiza `users/{uid}` e `usernames/{username}` no Firestore.
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
  });

  /// Faz logout do Firebase Auth.
  Future<void> signOut();
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DI — datasource → repository
// ─────────────────────────────────────────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (_) => AuthRemoteDataSource(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    dataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Stream do estado de autenticação — consumido pelo router como refresh.
// ─────────────────────────────────────────────────────────────────────────────

/// Emite [AuthUser] quando logado, null quando deslogado.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

// ─────────────────────────────────────────────────────────────────────────────
// Controller — ações de login / cadastro / logout
// ─────────────────────────────────────────────────────────────────────────────

/// Estado do controller: null = idle, data = sucesso (AuthUser), error = falha.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async => null; // idle por padrão

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Login com e-mail e senha.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AuthUser?>();
    state = await AsyncValue.guard<AuthUser?>(
      () => _repo.signInWithEmail(email: email, password: password),
    );
  }

  /// Cadastro manual.
  Future<void> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AuthUser?>();
    state = await AsyncValue.guard<AuthUser?>(
      () => _repo.signUpWithEmail(
        name: name,
        username: username,
        email: email,
        password: password,
      ),
    );
  }

  /// Login com Google.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading<AuthUser?>();
    state = await AsyncValue.guard<AuthUser?>(
      () => _repo.signInWithGoogle(),
    );
  }

  /// Grava username (fluxo pós-Google para novos usuários).
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
  }) async {
    state = const AsyncLoading<AuthUser?>();
    state = await AsyncValue.guard<AuthUser?>(
      () async {
        await _repo.setUsername(
          uid: uid,
          username: username,
          name: name,
          email: email,
        );
        // Retorna o usuário atualizado com hasUsername = true.
        return ref.read(authStateProvider).valueOrNull?.copyWith(hasUsername: true);
      },
    );
  }

  /// Logout.
  Future<void> signOut() async {
    state = const AsyncLoading<AuthUser?>();
    state = await AsyncValue.guard<AuthUser?>(
      () async {
        await _repo.signOut();
        return null;
      },
    );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);

// ─────────────────────────────────────────────────────────────────────────────
// Helper: converte erro do Firebase em mensagem PT-BR
// ─────────────────────────────────────────────────────────────────────────────

String firebaseAuthErrorMessage(Object error) {
  if (error is UsernameAlreadyTakenException) {
    return 'Este username já está em uso.';
  }
  if (error is ProfileLookupFailedException) {
    return AppStrings.authErrorProfileLookup;
  }
  if (error is GoogleSignInCancelledException) {
    return 'Login com Google cancelado.';
  }
  if (error is GoogleSignInMisconfiguredException) {
    // A pista técnica vai para o log; a tela não fala de SHA-1 com o usuário.
    if (kDebugMode) {
      debugPrint(
        '[Auth] Login com Google recusado com DEVELOPER_ERROR (ApiException: 10).\n'
        '       A SHA-1 deste keystore não está registrada no projeto Firebase,\n'
        '       e android/app/google-services.json está com "oauth_client" vazio.\n'
        '       Cadastre a SHA-1 no console, rebaixe o google-services.json e recompile.',
      );
    }
    return 'Login com Google indisponível nesta versão do app.';
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'A senha precisa ter ao menos 6 caracteres.';
      case 'invalid-email':
        return 'Informe um e-mail válido.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      default:
        return 'Erro de autenticação (${error.code}).';
    }
  }
  return 'Ocorreu um erro. Tente novamente.';
}

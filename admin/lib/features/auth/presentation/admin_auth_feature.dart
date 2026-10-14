import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Fronteira do módulo de autenticação administrativa.
abstract final class AdminAuthFeature {
  static const String name = 'Autenticação administrativa';
}

/// Dados mínimos necessários para decidir se uma sessão pode usar o painel.
class AdminAuthCandidate {
  const AdminAuthCandidate({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.providerIds,
    required this.claims,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final Set<String> providerIds;
  final Map<String, Object?> claims;
}

abstract interface class AdminAuthGateway {
  Stream<void> get authStateChanges;

  Future<void> useSessionPersistence();
  Future<AdminAuthCandidate?> refreshCurrentSession();
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
}

/// Adaptador do Firebase Auth. Não compartilha código com o cliente mobile.
class FirebaseAdminAuthGateway implements AdminAuthGateway {
  FirebaseAdminAuthGateway([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<void> get authStateChanges => _auth.authStateChanges().map((_) {});

  @override
  Future<void> useSessionPersistence() => _auth.setPersistence(Persistence.SESSION);

  @override
  Future<AdminAuthCandidate?> refreshCurrentSession() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user == null) return null;

    final tokenResult = await user.getIdTokenResult(true);
    return AdminAuthCandidate(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      providerIds: user.providerData.map((provider) => provider.providerId).toSet(),
      claims: Map<String, Object?>.from(tokenResult.claims ?? const <String, Object?>{}),
    );
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

enum AdminAccessState { loading, signedOut, authorized, unauthorized }

class AdminSession {
  const AdminSession({required this.uid, required this.email});

  final String uid;
  final String? email;
}

/// Coordena a validação completa de Auth antes de liberar qualquer conteúdo.
class AdminAuthController extends ChangeNotifier {
  AdminAuthController(this._gateway);

  final AdminAuthGateway _gateway;
  StreamSubscription<void>? _subscription;
  AdminAccessState _state = AdminAccessState.loading;
  AdminSession? _session;
  String? _loginError;
  bool _signingIn = false;
  bool _wasRejected = false;

  AdminAccessState get state => _state;
  AdminSession? get session => _session;
  String? get loginError => _loginError;
  bool get isSigningIn => _signingIn;

  Future<void> start() async {
    try {
      await _gateway.useSessionPersistence();
      _subscription = _gateway.authStateChanges.listen((_) => unawaited(_resolveSession()));
      await _resolveSession();
    } on Object {
      // Falhas de inicialização nunca liberam o shell administrativo.
      _state = AdminAccessState.signedOut;
      notifyListeners();
    }
  }

  Future<void> _resolveSession() async {
    _state = AdminAccessState.loading;
    notifyListeners();

    try {
      final candidate = await _gateway.refreshCurrentSession();
      if (candidate == null) {
        _session = null;
        _state = _wasRejected ? AdminAccessState.unauthorized : AdminAccessState.signedOut;
        notifyListeners();
        return;
      }

      final qualifies = candidate.emailVerified &&
          candidate.providerIds.contains(EmailAuthProvider.PROVIDER_ID) &&
          candidate.claims['admin'] == true;
      if (!qualifies) {
        _wasRejected = true;
        _session = null;
        await _gateway.signOut();
        _state = AdminAccessState.unauthorized;
        notifyListeners();
        return;
      }

      _wasRejected = false;
      _session = AdminSession(uid: candidate.uid, email: candidate.email);
      _state = AdminAccessState.authorized;
      notifyListeners();
    } on Object {
      _session = null;
      _state = AdminAccessState.signedOut;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _loginError = null;
    _signingIn = true;
    notifyListeners();
    try {
      await _gateway.signInWithEmailAndPassword(email: email.trim(), password: password);
      await _resolveSession();
    } on FirebaseAuthException catch (_) {
      _loginError = 'Não foi possível entrar com este e-mail e senha.';
    } on Object {
      _loginError = 'Não foi possível entrar agora. Tente novamente.';
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _wasRejected = false;
    _session = null;
    await _gateway.signOut();
    _state = AdminAccessState.signedOut;
    notifyListeners();
  }

  /// Libera a rota pública de login após uma rejeição administrativa.
  void returnToLogin() {
    _wasRejected = false;
    _state = AdminAccessState.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

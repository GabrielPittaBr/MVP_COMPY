import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/firebase_service.dart';
import '../../domain/entities/auth_user.dart';

/// Datasource remoto de autenticação.
///
/// Orquestra FirebaseAuth, GoogleSignIn e Firestore:
/// - `users/{uid}` armazena o perfil público (UserSummary).
/// - `usernames/{username}` é o índice de unicidade (doc id = username minúsculo).
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseService.instance.auth,
        _firestore = firestore ?? FirebaseService.instance.firestore,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>['email', 'profile'],
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  // ─────────────────────────────────────────────────────────────────────────
  // Stream de estado
  // ─────────────────────────────────────────────────────────────────────────

  /// Emite [AuthUser] quando autenticado, null quando deslogado.
  Stream<AuthUser?> authState() {
    return _auth.authStateChanges().asyncMap((User? firebaseUser) async {
      debugPrint('[Auth] authStateChanges emitiu: ${firebaseUser?.uid ?? 'null'}');
      if (firebaseUser == null) return null;
      debugPrint('[Auth] chamando _toAuthUser...');
      final result = await _toAuthUser(firebaseUser);
      debugPrint('[Auth] _toAuthUser concluído: hasUsername=${result.hasUsername}');
      return result;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login com e-mail / senha
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _toAuthUser(credential.user!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cadastro manual
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final String normalizedUsername = username.trim().toLowerCase();

    // 1. Verificar unicidade do username (leitura simples — transação abaixo
    //    garante consistência na escrita).
    final bool available = await isUsernameAvailable(normalizedUsername);
    if (!available) {
      throw const UsernameAlreadyTakenException();
    }

    // 2. Criar conta no Firebase Auth.
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final User firebaseUser = credential.user!;

    // 3. Atualizar displayName no Auth.
    await firebaseUser.updateDisplayName(name.trim());

    // 4. Gravar perfil e username no Firestore (operação atômica via batch).
    await _writeUserProfile(
      uid: firebaseUser.uid,
      name: name.trim(),
      username: normalizedUsername,
      email: email.trim(),
    );

    return AuthUser(
      uid: firebaseUser.uid,
      email: email.trim(),
      displayName: name.trim(),
      hasUsername: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login com Google
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signInWithGoogle() async {
    final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) {
      throw const GoogleSignInCancelledException();
    }

    final GoogleSignInAuthentication googleAuth =
        await googleAccount.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);
    final User firebaseUser = userCredential.user!;

    // Verificar se o usuário já tem perfil no Firestore.
    final bool hasProfile = await _userHasProfile(firebaseUser.uid);

    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      hasUsername: hasProfile,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Username
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isUsernameAvailable(String username) async {
    final String normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('usernames').doc(normalized).get();
    return !doc.exists;
  }

  /// Grava `users/{uid}` e `usernames/{username}` em um batch atômico.
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
  }) async {
    final String normalizedUsername = username.trim().toLowerCase();

    final bool available = await isUsernameAvailable(normalizedUsername);
    if (!available) {
      throw const UsernameAlreadyTakenException();
    }

    await _writeUserProfile(
      uid: uid,
      name: name,
      username: normalizedUsername,
      email: email,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait(<Future<void>>[
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthUser> _toAuthUser(User firebaseUser) async {
    final bool hasProfile = await _userHasProfile(firebaseUser.uid);
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      hasUsername: hasProfile,
    );
  }

  Future<bool> _userHasProfile(String uid) async {
    debugPrint('[Auth] _userHasProfile iniciando para $uid');
    try {
      debugPrint('[Auth] chamando Firestore .get()...');
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(uid).get()
              .timeout(const Duration(seconds: 10));
      debugPrint('[Auth] Firestore .get() concluído: exists=${doc.exists}');
      return doc.exists && (doc.data()?['handle'] as String?)?.isNotEmpty == true;
    } catch (e) {
      debugPrint('[Auth] _userHasProfile erro/timeout: $e');
      return false;
    }
  }

  /// Grava o perfil público em `users/{uid}` e o índice em `usernames/{username}`.
  Future<void> _writeUserProfile({
    required String uid,
    required String name,
    required String username,
    required String email,
  }) async {
    final WriteBatch batch = _firestore.batch();

    // Documento de perfil — compatível com UserSummary.fromMap().
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(uid);
    batch.set(
      userRef,
      <String, dynamic>{
        'id': uid,
        'name': name,
        'handle': '@$username',
        'avatarUrl': AppAssets.avatar(name),
        'email': email, // guardado para exibição interna; não exposto via UserSummary
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Índice de unicidade.
    final DocumentReference<Map<String, dynamic>> usernameRef =
        _firestore.collection('usernames').doc(username);
    batch.set(usernameRef, <String, dynamic>{'uid': uid});

    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceções de domínio
// ─────────────────────────────────────────────────────────────────────────────

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();
  @override
  String toString() => 'UsernameAlreadyTakenException';
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
  @override
  String toString() => 'GoogleSignInCancelledException';
}

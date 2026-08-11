import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../shared/models/sport.dart';
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

  static const Duration _profileLookupTimeout = Duration(seconds: 10);

  // ─────────────────────────────────────────────────────────────────────────
  // Stream de estado
  // ─────────────────────────────────────────────────────────────────────────

  /// Emite [AuthUser] quando autenticado, null quando deslogado.
  ///
  /// Usa `userChanges()` em vez de `authStateChanges()` para também reagir a
  /// mudanças de perfil: `setUsername()` chama `updateDisplayName()`, e é essa
  /// emissão que faz o nome corrigido chegar à saudação da Home sem exigir
  /// reinício do app. O custo é uma leitura extra em `users/{uid}` por
  /// emissão (inclui a renovação de token, ~1x/hora).
  Stream<AuthUser?> authState() {
    return _auth.userChanges().asyncMap((User? firebaseUser) async {
      if (firebaseUser == null) return null;
      return _toAuthUser(firebaseUser);
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
      // Conta recém-criada: o perfil nasce sem o campo de esportes, então o
      // guard leva este usuário para o onboarding antes da Home.
      hasFavoriteSports: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login com Google
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signInWithGoogle() async {
    final UserCredential userCredential =
        await _auth.signInWithCredential(await _googleCredential());

    return _toAuthUser(userCredential.user!);
  }

  /// Abre o seletor do Google e devolve a credencial resultante.
  ///
  /// Serve ao login e à reautenticação da exclusão de conta: nos dois casos o
  /// que se quer é a mesma coisa — prova recente de que quem está ali é dono
  /// daquela conta Google.
  Future<OAuthCredential> _googleCredential() async {
    final GoogleSignInAccount? googleAccount;
    try {
      googleAccount = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      // `sign_in_failed` com `ApiException: 10` (DEVELOPER_ERROR) não é falha
      // de rede nem de credencial: é o app não estar registrado no projeto
      // Firebase para este certificado. Sem distinguir aqui, o usuário via
      // "Ocorreu um erro. Tente novamente." e tentar de novo nunca resolvia.
      if (e.code == 'sign_in_failed' && '${e.message}'.contains('10')) {
        throw const GoogleSignInMisconfiguredException();
      }
      rethrow;
    }

    if (googleAccount == null) {
      throw const GoogleSignInCancelledException();
    }

    final GoogleSignInAuthentication googleAuth =
        await googleAccount.authentication;

    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Username
  // ─────────────────────────────────────────────────────────────────────────

  /// [forUid] é o dono esperado do username. Sem ele, qualquer documento
  /// existente bloqueia — é o caso do cadastro por e-mail, onde a conta ainda
  /// não existe.
  Future<bool> isUsernameAvailable(String username, {String? forUid}) async {
    final String normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('usernames').doc(normalized).get();
    return usernameAvailableFor(
      existing: doc.exists ? doc.data() : null,
      forUid: forUid,
    );
  }

  /// Um documento de username já existente só bloqueia quem **não** é o dono.
  ///
  /// Sem esta ressalva, o usuário mandado de volta para `/username` por uma
  /// leitura de perfil que falhou levava `UsernameAlreadyTakenException` no
  /// username dele mesmo, e não tinha como sair da tela.
  @visibleForTesting
  static bool usernameAvailableFor({
    required Map<String, dynamic>? existing,
    String? forUid,
  }) {
    if (existing == null) return true;
    return forUid != null && existing['uid'] == forUid;
  }

  /// Grava `users/{uid}` e `usernames/{username}` em um batch atômico.
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
  }) async {
    final String normalizedUsername = username.trim().toLowerCase();
    final String trimmedName = name.trim();

    final bool available =
        await isUsernameAvailable(normalizedUsername, forUid: uid);
    if (!available) {
      throw const UsernameAlreadyTakenException();
    }

    await _writeUserProfile(
      uid: uid,
      name: trimmedName,
      username: normalizedUsername,
      email: email,
    );

    // O nome que a Home exibe (`greetingNameProvider`) vem de
    // `AuthUser.displayName`, ou seja, do Firebase Auth — não do Firestore.
    // Sem este passo, o nome corrigido nesta tela ficaria só em
    // `users/{uid}.name` e a saudação continuaria mostrando o do Google.
    final User? current = _auth.currentUser;
    if (current != null &&
        current.uid == uid &&
        current.displayName != trimmedName) {
      await current.updateDisplayName(trimmedName);
    }
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
  // Exclusão de conta
  // ─────────────────────────────────────────────────────────────────────────

  /// `true` quando a exclusão vai precisar da senha para reautenticar.
  ///
  /// Com Google e senha vinculados ao mesmo uid, o Google ganha: reautenticar
  /// por lá não faz o usuário digitar nada.
  bool signedInWithPassword() {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    final Iterable<String> providers =
        user.providerData.map((UserInfo info) => info.providerId);
    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) return false;
    return providers.contains(EmailAuthProvider.PROVIDER_ID);
  }

  /// Apaga a conta e os documentos que [_writeUserProfile] criou.
  ///
  /// **A ordem é o contrato:**
  ///
  /// 1. **Reautenticar.** `User.delete()` exige login recente. Descobrir isso
  ///    só no fim deixaria o perfil apagado com a conta ainda viva — o pior
  ///    estado possível, porque o guard do router mandaria o usuário para
  ///    `/username` como se fosse gente nova.
  /// 2. **Firestore.** Todas as regras exigem `signedIn()`: depois que a
  ///    conta some não há mais como apagar `users/{uid}`.
  /// 3. **Auth.**
  ///
  /// Fora do escopo de propósito: eventos criados e mensagens de chat
  /// continuam existindo, com nome e avatar congelados. As regras tornam
  /// `creator` e `members` imutáveis e não existe "sair do evento" — limpar
  /// isso é outra tarefa, com outras regras.
  Future<void> deleteAccount({String? password}) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Não há usuário autenticado para excluir.',
      );
    }

    await _reauthenticate(user, password);
    await _deleteUserDocuments(user.uid);
    await user.delete();
    await _googleSignIn.signOut();
  }

  /// Prova recente de identidade, pelo provedor que a conta usa.
  Future<void> _reauthenticate(User user, String? password) async {
    final Iterable<String> providers =
        user.providerData.map((UserInfo info) => info.providerId);

    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      await user.reauthenticateWithCredential(await _googleCredential());
      return;
    }

    if (!providers.contains(EmailAuthProvider.PROVIDER_ID)) {
      // Conta sem provedor conhecido: não há o que reautenticar. Segue e
      // deixa o `delete()` falar por si.
      return;
    }

    final String email = user.email ?? '';
    if (email.isEmpty || password == null || password.isEmpty) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Senha necessária para excluir a conta.',
      );
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// O inverso exato de [_writeUserProfile], no mesmo batch atômico.
  Future<void> _deleteUserDocuments(String uid) async {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();
    final String? usernameDocId =
        usernameDocIdFromHandle(snapshot.data()?['handle'] as String?);

    final WriteBatch batch = _firestore.batch();

    // A regra de `usernames` olha `resource.data.uid`, e num documento
    // inexistente `resource` é nulo — pedir a exclusão dele derruba o batch
    // inteiro com PERMISSION_DENIED. Por isso o id só entra quando existe.
    if (usernameDocId != null) {
      batch.delete(_firestore.collection('usernames').doc(usernameDocId));
    }
    batch.delete(userRef.collection('private').doc('contact'));
    batch.delete(userRef);

    await batch.commit();
  }

  /// Id do documento em `usernames` a partir do `handle` do perfil.
  ///
  /// O índice é chaveado pelo username (`joao`), enquanto o perfil guarda o
  /// handle (`@joao`) — sem essa conversão a reserva do nome sobrevive à
  /// conta e ninguém mais consegue usá-lo.
  @visibleForTesting
  static String? usernameDocIdFromHandle(String? handle) {
    final String normalized =
        (handle ?? '').trim().replaceFirst('@', '').toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  /// Uma leitura de `users/{uid}` alimenta os dois sinais do guard.
  Future<AuthUser> _toAuthUser(User firebaseUser) async {
    final Map<String, dynamic>? data = await _fetchUserData(firebaseUser.uid);
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      hasUsername: (data?['handle'] as String?)?.isNotEmpty == true,
      hasFavoriteSports: Sport.hasStoredFavorites(data),
    );
  }

  /// Lê `users/{uid}`. `null` quando o documento ainda não existe.
  ///
  /// Falha de leitura **estoura** em vez de devolver "não tem perfil". Mentir
  /// era o bug: um usuário já cadastrado com internet lenta batia no timeout,
  /// era tratado como novo e mandado para `/username` — onde confirmar o
  /// próprio username dava "username já em uso". Um erro explícito na tela é
  /// pior de ver e melhor de viver do que um cadastro fantasma.
  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(uid).get()
              .timeout(_profileLookupTimeout);
      return doc.exists ? (doc.data() ?? <String, dynamic>{}) : null;
    } catch (error) {
      debugPrint('[Auth] leitura de users/$uid falhou: $error');
      throw ProfileLookupFailedException(error);
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
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Contato privado (RN-06). `users/{uid}` é legível por qualquer
    // autenticado, então o e-mail não pode morar lá — a entidade Dart nunca o
    // expunha, mas a regra expunha. Mesmo batch: perfil e contato nascem
    // juntos ou não nascem.
    final DocumentReference<Map<String, dynamic>> contactRef =
        userRef.collection('private').doc('contact');
    batch.set(
      contactRef,
      <String, dynamic>{'email': email},
      SetOptions(merge: true),
    );

    // Índice de unicidade. Merge porque no re-cadastro o documento já existe
    // e `set` sem merge sobrescreveria o documento inteiro — a regra permite
    // o update do dono justamente para este caminho.
    final DocumentReference<Map<String, dynamic>> usernameRef =
        _firestore.collection('usernames').doc(username);
    batch.set(
      usernameRef,
      <String, dynamic>{'uid': uid},
      SetOptions(merge: true),
    );

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

/// O app não está registrado no projeto Firebase para o certificado que
/// assinou este build (`ApiException: 10` / DEVELOPER_ERROR).
///
/// Causa quase sempre a mesma: a SHA-1 do keystore não está cadastrada no
/// Firebase Console, e por isso o `google-services.json` volta do
/// `flutterfire configure` com `oauth_client` **vazio**. Tentar de novo nunca
/// resolve — é configuração, não falha transitória.
class GoogleSignInMisconfiguredException implements Exception {
  const GoogleSignInMisconfiguredException();
  @override
  String toString() => 'GoogleSignInMisconfiguredException';
}

/// A leitura de `users/{uid}` falhou (timeout, rede, permissão).
///
/// Existe para o app **não** confundir "não consegui saber" com "não tem
/// perfil": o segundo manda o usuário para o cadastro, o primeiro pede uma
/// nova tentativa.
class ProfileLookupFailedException implements Exception {
  const ProfileLookupFailedException(this.cause);
  final Object cause;
  @override
  String toString() => 'ProfileLookupFailedException($cause)';
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
  @override
  String toString() => 'GoogleSignInCancelledException';
}

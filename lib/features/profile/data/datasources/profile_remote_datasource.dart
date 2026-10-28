import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/avatar_storage.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/models/sport.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._firestore, this._avatars, {FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final AvatarStorage _avatars;
  final FirebaseAuth _auth;

  void _requireOwner(String uid) {
    if (uid.isEmpty || _auth.currentUser?.uid != uid) {
      throw StateError('Usuário não autenticado para editar este perfil.');
    }
  }

  Future<void> updatePublicDetails(String uid, String name, String bio) async {
    _requireOwner(uid);
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'name': name,
        'nameLower': TextNormalizer.normalize(name),
        'bio': bio,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateAuthDisplayName(String uid, String name) async {
    _requireOwner(uid);
    if (_auth.currentUser!.displayName != name) {
      await _auth.currentUser!.updateDisplayName(name);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchById(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Grava o array de esportes favoritos em `users/{uid}`.
  ///
  /// `set` com merge, não `update`: preserva os demais campos do perfil em
  /// vez de exigir que o chamador conheça todos eles.
  ///
  /// Não serve para criar o documento do zero — um `users/{uid}` só com este
  /// campo é recusado por `validProfile()`, que exige `id == userId`. Nem
  /// precisa: quem ainda não tem perfil é mandado para `/username` antes de
  /// chegar à escolha de esportes.
  Future<void> updateFavoriteSports(String userId, List<String> sports) {
    return _firestore.collection('users').doc(userId).set(
      <String, dynamic>{Sport.favoriteSportsField: sports},
      SetOptions(merge: true),
    );
  }

  /// Envia a foto ao Storage e devolve a URL de download.
  Future<String> uploadAvatar(String userId, Uint8List jpeg) =>
      _avatars.upload(userId, jpeg);

  /// Grava `users/{uid}.avatarUrl`. Merge pelo mesmo motivo de
  /// [updateFavoriteSports].
  Future<void> updateAvatarUrl(String userId, String avatarUrl) {
    return _firestore.collection('users').doc(userId).set(
      <String, dynamic>{'avatarUrl': avatarUrl},
      SetOptions(merge: true),
    );
  }

  /// Usuários cujo handle começa por [handlePrefix] (sem o `@`).
  ///
  /// O handle é gravado como `@username` em minúsculo, então a faixa de
  /// prefixo é montada sobre `@$handlePrefix`. `` é o maior caractere
  /// da tabela — ele fecha a faixa em "tudo que começa com o prefixo".
  ///
  /// Campo único ordenado: o Firestore cria o índice sozinho, sem entrada em
  /// `firestore.indexes.json`.
  Future<QuerySnapshot<Map<String, dynamic>>> searchByHandlePrefix(
    String handlePrefix, {
    int limit = 20,
  }) {
    final start = '@$handlePrefix';
    return _firestore
        .collection('users')
        .orderBy('handle')
        .startAt(<Object>[start])
        .endAt(<Object>['$start'])
        .limit(limit)
        .get();
  }

  /// Perfis cujo nome normalizado começa por [namePrefix].
  ///
  /// A consulta é remota e ordenada por `nameLower`; ela não baixa todos os
  /// perfis para filtrar no cliente.
  Future<QuerySnapshot<Map<String, dynamic>>> searchByNamePrefix(
    String namePrefix, {
    int limit = 20,
  }) {
    final start = TextNormalizer.normalize(namePrefix);
    return _firestore
        .collection('users')
        .orderBy('nameLower')
        .startAt(<Object>[start])
        .endAt(<Object>['$start'])
        .limit(limit)
        .get();
  }
}

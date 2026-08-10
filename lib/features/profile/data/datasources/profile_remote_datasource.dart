import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/sport.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  /// Grava o array de esportes favoritos em `users/{uid}`.
  ///
  /// `set` com merge, não `update`: o documento pode ainda não existir (conta
  /// Google que fechou o app na tela de username) e `update` estouraria.
  Future<void> updateFavoriteSports(String userId, List<String> sports) {
    return _firestore.collection('users').doc(userId).set(
      <String, dynamic>{Sport.favoriteSportsField: sports},
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
}

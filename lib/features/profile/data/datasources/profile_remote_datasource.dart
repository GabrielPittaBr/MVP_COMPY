import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String userId) {
    return _firestore.collection('users').doc(userId).get();
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

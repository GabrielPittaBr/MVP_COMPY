import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore da Home. Quando ligado, lê a coleção `events`
/// ordenada por proximidade. Hoje serve como esqueleto — `kUseFirebaseRepos`
/// está desligado e o repositório usa fixtures de [MockEvents].
class HomeRemoteDataSource {
  HomeRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Stream dos N eventos mais próximos do usuário.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchNearbyEvents({int limit = 20}) {
    return _firestore
        .collection('events')
        .orderBy('dateTime')
        .limit(limit)
        .snapshots();
  }
}

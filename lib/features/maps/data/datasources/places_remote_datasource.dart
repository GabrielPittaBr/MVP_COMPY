import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore dos locais esportivos. Esqueleto.
class PlacesRemoteDataSource {
  PlacesRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<QuerySnapshot<Map<String, dynamic>>> fetchAll() {
    return _firestore.collection('places').get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchBySport(String sportKey) {
    return _firestore
        .collection('places')
        .where('sport', isEqualTo: sportKey)
        .get();
  }
}

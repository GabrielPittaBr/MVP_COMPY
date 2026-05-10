import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }
}

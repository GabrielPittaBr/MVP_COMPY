import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore dos eventos. Esqueleto.
class EventsRemoteDataSource {
  EventsRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() {
    return _firestore.collection('events').snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String id) {
    return _firestore.collection('events').doc(id).get();
  }

  Future<void> join(String eventId, String userId) {
    return _firestore.collection('events').doc(eventId).update(<String, Object?>{
      'participants': FieldValue.arrayUnion(<String>[userId]),
      'remainingSpots': FieldValue.increment(-1),
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> create(
    Map<String, dynamic> data,
  ) {
    return _firestore.collection('events').add(data);
  }
}

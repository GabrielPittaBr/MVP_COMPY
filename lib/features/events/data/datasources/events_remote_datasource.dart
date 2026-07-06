import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/events_repository.dart';

/// Datasource Firestore dos eventos.
class EventsRemoteDataSource {
  EventsRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() {
    return _firestore.collection('events').snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String id) {
    return _firestore.collection('events').doc(id).get();
  }

  /// Registra a participação de [user] (mapa de `UserSummary`) em uma
  /// transação: valida vagas e decrementa atomicamente, evitando corrida
  /// entre dois joins simultâneos (RN-05). Idempotente para quem já entrou.
  Future<void> join(String eventId, Map<String, dynamic> user) {
    final docRef = _firestore.collection('events').doc(eventId);
    return _firestore.runTransaction<void>((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('Evento $eventId não encontrado');
      }

      final participants = (data['participants'] as List<dynamic>? ?? <dynamic>[]);
      final alreadyJoined = participants
          .any((p) => p is Map && p['id'] == user['id']);
      if (alreadyJoined) return;

      final remaining = (data['remainingSpots'] as int?) ?? 0;
      if (remaining <= 0) throw const EventFullException();

      tx.update(docRef, <String, Object?>{
        'participants': FieldValue.arrayUnion(<Map<String, dynamic>>[user]),
        'remainingSpots': remaining - 1,
      });
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> create(
    Map<String, dynamic> data,
  ) {
    return _firestore.collection('events').add(data);
  }
}

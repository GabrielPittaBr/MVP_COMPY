import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/events_repository.dart';

/// Datasource Firestore dos eventos.
class EventsRemoteDataSource {
  EventsRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Página de eventos ordenada por data. Passe o último documento da
  /// página anterior em [startAfter] para buscar a próxima (paginação
  /// com `startAfterDocument`).
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('events').orderBy('dateTime').limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Busca por prefixo do título (campo `titleLower`, minúsculo).
  Future<QuerySnapshot<Map<String, dynamic>>> searchByTitlePrefix(
    String prefixLower, {
    int limit = 20,
  }) {
    return _firestore
        .collection('events')
        .orderBy('titleLower')
        // O range fecha com U+F8FF (último code point útil) concatenado
        // ao prefixo — caractere invisível no fim da string do endAt.
        .startAt(<String>[prefixLower])
        .endAt(<String>['$prefixLower'])
        .limit(limit)
        .get();
  }

  /// Busca por modalidades esportivas (campo `sport` = nome do enum).
  Future<QuerySnapshot<Map<String, dynamic>>> searchBySports(
    List<String> sportNames, {
    int limit = 20,
  }) {
    return _firestore
        .collection('events')
        .where('sport', whereIn: sportNames)
        .limit(limit)
        .get();
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

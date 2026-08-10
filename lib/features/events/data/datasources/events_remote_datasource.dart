import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/events_repository.dart';

/// Datasource Firestore dos eventos.
class EventsRemoteDataSource {
  EventsRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Página de eventos ordenada por data. Passe o último documento da
  /// página anterior em [startAfter] para buscar a próxima (paginação
  /// com `startAfterDocument`).
  ///
  /// [sportName] (nome do enum `Sport`) e [skillLevelNames] (nomes do enum
  /// `SkillLevel`) filtram modalidade e nível; [dayStart]/[dayEnd] recortam
  /// um dia. Cada combinação de igualdade com o `orderBy('dateTime')` exige
  /// um índice composto — todos declarados em `firestore.indexes.json`.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
    String? sportName,
    List<String> skillLevelNames = const <String>[],
    DateTime? dayStart,
    DateTime? dayEnd,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('events');
    if (sportName != null) {
      query = query.where('sport', isEqualTo: sportName);
    }
    if (skillLevelNames.isNotEmpty) {
      query = query.where('skillLevel', whereIn: skillLevelNames);
    }
    if (dayStart != null && dayEnd != null) {
      query = query
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('dateTime', isLessThan: Timestamp.fromDate(dayEnd));
    }
    query = query.orderBy('dateTime').limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Eventos criados por [uid] — seção "Criados por mim".
  ///
  /// Sem paginação de propósito: o volume por usuário é baixo e o [limit]
  /// serve só de teto. Os critérios da folha de filtros também ficam de
  /// fora da consulta e são aplicados no cliente pelo repositório —
  /// combiná-los aqui exigiria um índice composto por combinação
  /// (`creator.id + sport + dateTime`, `+ skillLevel`, `+ dia`…), e o
  /// motivo de filtrar no servidor na lista principal (não estragar a
  /// paginação) não existe numa lista que vem inteira.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchCreatedBy(
    String uid, {
    int limit = 50,
  }) {
    return _firestore
        .collection('events')
        .where('creator.id', isEqualTo: uid)
        .orderBy('dateTime')
        .limit(limit)
        .get();
  }

  /// Eventos em que [uid] está inscrito — seção "Participando".
  ///
  /// Consulta `participantIds` (array de strings) e não `participants`
  /// (array de mapas): `arrayContains` sobre mapas exigiria o mapa inteiro
  /// idêntico, então bastaria o usuário trocar de avatar para sumir da
  /// própria lista. Mesmas ressalvas de paginação e filtro do
  /// [fetchCreatedBy].
  Future<QuerySnapshot<Map<String, dynamic>>> fetchJoinedBy(
    String uid, {
    int limit = 50,
  }) {
    return _firestore
        .collection('events')
        .where('participantIds', arrayContains: uid)
        .orderBy('dateTime')
        .limit(limit)
        .get();
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

      // Basta olhar o array de ids — a varredura dos mapas fica só como
      // rede para documentos anteriores à tarefa 12, que ainda não têm
      // `participantIds` e aceitariam o mesmo usuário duas vezes.
      final ids = (data['participantIds'] as List<dynamic>? ?? <dynamic>[]);
      final alreadyJoined = ids.contains(user['id']) ||
          (data['participants'] as List<dynamic>? ?? <dynamic>[])
              .any((p) => p is Map && p['id'] == user['id']);
      if (alreadyJoined) return;

      final remaining = (data['remainingSpots'] as int?) ?? 0;
      if (remaining <= 0) throw const EventFullException();

      tx.update(docRef, <String, Object?>{
        'participants': FieldValue.arrayUnion(<Map<String, dynamic>>[user]),
        // Os dois arrays crescem no mesmo update, atomicamente — é o que a
        // regra `isJoin()` de firestore.rules exige para autorizar a
        // escrita, e o que impede a lista de ids de atrasar em relação aos
        // participantes.
        'participantIds': FieldValue.arrayUnion(<Object?>[user['id']]),
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

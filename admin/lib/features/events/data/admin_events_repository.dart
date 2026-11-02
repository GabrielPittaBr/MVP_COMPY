import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/operations/admin_operations.dart';

/// Fase do Evento Esportivo. Não é gravada: deriva do relógio, como no app.
enum AdminEventStatus { scheduled, happening, ended }

/// Folga depois do fim previsto em que o evento ainda está acontecendo.
/// Espelha `kEventEndTolerance` do app e a Function `autoEndOverdueEvents`.
const Duration adminEventEndTolerance = Duration(hours: 1);

/// Identidade pública copiada no evento (`creator` e `participants`).
class AdminEventPerson {
  const AdminEventPerson({
    required this.uid,
    required this.name,
    required this.handle,
    required this.avatarUrl,
  });

  final String uid;
  final String name;
  final String handle;
  final String avatarUrl;

  /// `null` quando o item não é um mapa ou não tem `id`.
  static AdminEventPerson? tryFromMap(Object? raw) {
    if (raw is! Map || raw['id'] is! String || (raw['id'] as String).isEmpty) {
      return null;
    }
    String text(String key) => raw[key] is String ? raw[key] as String : '';
    return AdminEventPerson(
      uid: raw['id'] as String,
      name: text('name'),
      handle: text('handle'),
      avatarUrl: text('avatarUrl'),
    );
  }
}

/// Leitura tolerante de `events/{id}`: o painel precisa mostrar (e poder
/// excluir) até documentos antigos ou malformados, então campo ausente vira
/// valor vazio em vez de erro.
class AdminEventRecord {
  const AdminEventRecord({
    required this.id,
    required this.title,
    required this.sport,
    required this.skillLevel,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.placeId,
    required this.placeName,
    required this.placeAddress,
    required this.totalSpots,
    required this.remainingSpots,
    required this.organizer,
    required this.participants,
    required this.description,
    required this.endedAt,
    required this.endedAutomatically,
    required this.ratedByCount,
  });

  final String id;
  final String title;
  final String sport;
  final String skillLevel;
  final DateTime? startsAt;

  /// Fim previsto: `endsAt` gravado, ou início + duração (1h nos legados).
  final DateTime? endsAt;

  /// Texto livre de eventos antigos; nos novos, "Local, Cidade".
  final String location;
  final String? placeId;
  final String? placeName;
  final String? placeAddress;
  final int totalSpots;
  final int remainingSpots;
  final AdminEventPerson? organizer;
  final List<AdminEventPerson> participants;
  final String description;
  final DateTime? endedAt;
  final bool endedAutomatically;
  final int ratedByCount;

  factory AdminEventRecord.fromDocument(String id, Map<String, dynamic> data) {
    String text(String key) => data[key] is String ? data[key] as String : '';
    int number(String key) => data[key] is int ? data[key] as int : 0;
    final startsAt = _date(data['dateTime']);
    final duration = data['durationMinutes'] is int
        ? data['durationMinutes'] as int
        : 60;
    final snapshot = data['placeSnapshot'];
    final rawParticipants = data['participants'];
    final ratedBy = data['ratedBy'];
    return AdminEventRecord(
      id: id,
      title: text('title'),
      sport: text('sport'),
      skillLevel: text('skillLevel'),
      startsAt: startsAt,
      endsAt:
          _date(data['endsAt']) ?? startsAt?.add(Duration(minutes: duration)),
      location: text('location'),
      placeId: data['placeId'] is String ? data['placeId'] as String : null,
      placeName: snapshot is Map && snapshot['name'] is String
          ? snapshot['name'] as String
          : null,
      placeAddress: snapshot is Map
          ? _formatAddress(snapshot['address'])
          : null,
      totalSpots: number('totalSpots'),
      remainingSpots: number('remainingSpots'),
      organizer: AdminEventPerson.tryFromMap(data['creator']),
      participants: List<AdminEventPerson>.unmodifiable(<AdminEventPerson>[
        if (rawParticipants is List)
          for (final raw in rawParticipants) ?AdminEventPerson.tryFromMap(raw),
      ]),
      description: text('description'),
      endedAt: _date(data['endedAt']),
      endedAutomatically: data['endedAutomatically'] == true,
      ratedByCount: ratedBy is List ? ratedBy.whereType<String>().length : 0,
    );
  }

  /// Mesma regra do app: encerrado se tem `endedAt` ou se passou do fim
  /// previsto mais a folga. Evento sem data não pode estar aberto.
  AdminEventStatus statusAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (endedAt != null || start == null || end == null) {
      return AdminEventStatus.ended;
    }
    if (now.isBefore(start)) return AdminEventStatus.scheduled;
    if (now.isBefore(end.add(adminEventEndTolerance))) {
      return AdminEventStatus.happening;
    }
    return AdminEventStatus.ended;
  }
}

DateTime? _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  _ => null,
};

String? _formatAddress(Object? raw) {
  if (raw is! Map) return null;
  String part(String key) =>
      raw[key] is String ? (raw[key] as String).trim() : '';
  final street = part('street');
  final number = part('number');
  final city = part('city');
  final state = part('state');
  final lines = <String>[
    number.isEmpty ? street : '$street, $number',
    part('neighborhood'),
    state.isEmpty ? city : '$city/$state',
  ].where((line) => line.isNotEmpty);
  return lines.isEmpty ? null : lines.join(' – ');
}

/// Título como o app grava em `titleLower`: só minúsculo, sem tirar acento.
String normalizeAdminEventTitle(String value) => value.trim().toLowerCase();

class AdminEventsFilters {
  const AdminEventsFilters({this.titlePrefix = '', this.sport});

  final String titlePrefix;
  final String? sport;

  AdminEventsFilters copyWith({
    String? titlePrefix,
    String? sport,
    bool clearSport = false,
  }) => AdminEventsFilters(
    titlePrefix: titlePrefix ?? this.titlePrefix,
    sport: clearSport ? null : sport ?? this.sport,
  );

  @override
  bool operator ==(Object other) =>
      other is AdminEventsFilters &&
      other.titlePrefix == titlePrefix &&
      other.sport == sport;

  @override
  int get hashCode => Object.hash(titlePrefix, sport);
}

/// Contrato das consultas da lista. Sem busca, os eventos mais recentes vêm
/// primeiro; com busca, a ordem é a do título (prefixo em `titleLower`). Os
/// pares com `sport` usam os índices compostos `sport + dateTime desc` e
/// `sport + titleLower` de `firestore.indexes.json`.
class AdminEventsQueryPlan {
  const AdminEventsQueryPlan({required this.sport, required this.titlePrefix});

  final String? sport;
  final String titlePrefix;

  static const int pageSize = 20;

  bool get ordersByTitle => titlePrefix.isNotEmpty;

  factory AdminEventsQueryPlan.fromFilters(AdminEventsFilters filters) =>
      AdminEventsQueryPlan(
        sport: filters.sport,
        titlePrefix: normalizeAdminEventTitle(filters.titlePrefix),
      );
}

abstract interface class AdminEventCursor {}

class AdminEventsPageSnapshot {
  const AdminEventsPageSnapshot({
    required this.events,
    required this.cursor,
    required this.isFromCache,
  });

  final List<AdminEventRecord> events;
  final AdminEventCursor? cursor;
  final bool isFromCache;
}

class AdminEventDeletionResult {
  const AdminEventDeletionResult({
    required this.eventId,
    required this.completedAt,
  });

  final String eventId;
  final DateTime completedAt;

  factory AdminEventDeletionResult.fromCallable(Object? value) {
    final completedAt = value is Map && value['completedAt'] is String
        ? DateTime.tryParse(value['completedAt'] as String)
        : null;
    if (value is! Map ||
        value['eventId'] is! String ||
        (value['eventId'] as String).isEmpty ||
        completedAt == null) {
      throw const FormatException('Retorno da exclusão de evento inválido.');
    }
    return AdminEventDeletionResult(
      eventId: value['eventId'] as String,
      completedAt: completedAt.toUtc(),
    );
  }
}

typedef AdminEventsCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, Object?> payload,
);

abstract interface class AdminEventsRepository {
  Future<AdminEventsPageSnapshot> searchEvents(
    AdminEventsFilters filters, {
    AdminEventCursor? after,
  });

  /// `null` quando o evento não existe.
  Future<AdminEventRecord?> loadEvent(String id);

  /// Os eventos mais recentes organizados por [uid], do mais novo ao mais
  /// antigo, até [limit].
  Future<List<AdminEventRecord>> loadOrganizedBy(
    String uid, {
    int limit = AdminEventsQueryPlan.pageSize,
  });

  Future<AdminEventDeletionResult> deleteEvent({
    required String eventId,
    required String reason,
    required String operationId,
  });
}

class FirebaseAdminEventsRepository implements AdminEventsRepository {
  FirebaseAdminEventsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.invoker,
  }) : _injectedFirestore = firestore,
       _injectedFunctions = functions;

  final FirebaseFirestore? _injectedFirestore;
  final FirebaseFunctions? _injectedFunctions;

  /// Substitui a Callable nos testes, que conferem nome e payload exatos.
  final AdminEventsCallableInvoker? invoker;

  // Resolvidos só no uso: o router cria o repositório antes de qualquer
  // leitura, e os testes de tela não inicializam o Firebase.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  @override
  Future<AdminEventsPageSnapshot> searchEvents(
    AdminEventsFilters filters, {
    AdminEventCursor? after,
  }) async {
    final plan = AdminEventsQueryPlan.fromFilters(filters);
    Query<Map<String, dynamic>> query = _events;
    if (plan.sport != null) {
      query = query.where('sport', isEqualTo: plan.sport);
    }
    if (plan.ordersByTitle) {
      query = query
          .orderBy('titleLower')
          .startAt(<Object?>[plan.titlePrefix])
          .endAt(<Object?>['${plan.titlePrefix}']);
    } else {
      query = query.orderBy('dateTime', descending: true);
    }
    if (after != null) {
      if (after is! _FirestoreAdminEventCursor) {
        throw ArgumentError.value(after, 'after', 'Cursor incompatível.');
      }
      query = query.startAfterDocument(after.document);
    }
    final result = await query.limit(AdminEventsQueryPlan.pageSize).get();
    return AdminEventsPageSnapshot(
      events: result.docs
          .map((doc) => AdminEventRecord.fromDocument(doc.id, doc.data()))
          .toList(growable: false),
      cursor: result.docs.length == AdminEventsQueryPlan.pageSize
          ? _FirestoreAdminEventCursor(result.docs.last)
          : null,
      isFromCache: result.metadata.isFromCache,
    );
  }

  @override
  Future<AdminEventRecord?> loadEvent(String id) async {
    final doc = await _events.doc(id).get();
    final data = doc.data();
    return data == null ? null : AdminEventRecord.fromDocument(doc.id, data);
  }

  @override
  Future<List<AdminEventRecord>> loadOrganizedBy(
    String uid, {
    int limit = AdminEventsQueryPlan.pageSize,
  }) async {
    // Índice `creator.id + dateTime desc`: o do app ("Criados por mim") é
    // crescente, e o Firestore não percorre um índice composto ao contrário.
    final result = await _events
        .where('creator.id', isEqualTo: uid)
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .get();
    return result.docs
        .map((doc) => AdminEventRecord.fromDocument(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<AdminEventDeletionResult> deleteEvent({
    required String eventId,
    required String reason,
    required String operationId,
  }) async {
    final payload = <String, Object?>{
      'eventId': eventId,
      'reason': normalizeAdminReason(reason),
      'operationId': operationId,
    };
    final testInvoker = invoker;
    final Object? response;
    if (testInvoker != null) {
      response = await testInvoker('deleteEvent', payload);
    } else {
      final functions =
          _injectedFunctions ??
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      response =
          (await functions.httpsCallable('deleteEvent').call<Object?>(payload))
              .data;
    }
    return AdminEventDeletionResult.fromCallable(response);
  }
}

class _FirestoreAdminEventCursor implements AdminEventCursor {
  const _FirestoreAdminEventCursor(this.document);

  final DocumentSnapshot<Map<String, dynamic>> document;
}

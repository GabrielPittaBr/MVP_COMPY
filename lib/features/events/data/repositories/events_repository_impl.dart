import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/events_filter.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_datasource.dart';
import '../datasources/in_memory_events_store.dart';

class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._remote);
  final EventsRemoteDataSource? _remote;

  @override
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize = 10,
    EventsFilter filter = const EventsFilter(),
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      // Mock: o cursor é o offset na lista (já filtrada) em memória.
      final all = InMemoryEventsStore.instance.snapshotMatching(filter);
      final offset = (cursor as int?) ?? 0;
      final items = all.skip(offset).take(pageSize).toList();
      final nextOffset = offset + items.length;
      return PagedResult<Event>(
        items: items,
        cursor: nextOffset,
        hasMore: nextOffset < all.length,
      );
    }

    final snapshot = await _remote.fetchPage(
      startAfter: cursor as DocumentSnapshot<Map<String, dynamic>>?,
      limit: pageSize,
      sportName: filter.sport?.name,
      skillLevelNames: <String>[
        for (final level in filter.matchingSkillLevels) level.name,
      ],
      dayStart: filter.dayStart,
      dayEnd: filter.dayEnd,
    );
    final items = snapshot.docs
        .map((doc) => Event.fromMap(doc.id, doc.data()))
        .toList();
    return PagedResult<Event>(
      items: items,
      // Último documento da página — cursor do startAfterDocument.
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  @override
  Future<List<Event>> fetchCreatedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.createdBy(uid, filter);
    }
    return _matching(await _remote.fetchCreatedBy(uid), filter);
  }

  @override
  Future<List<Event>> fetchJoinedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.joinedBy(uid, filter);
    }
    return _matching(await _remote.fetchJoinedBy(uid), filter);
  }

  /// Aplica o filtro depois de buscar — legítimo aqui porque as duas seções
  /// vêm inteiras (ver `EventsRemoteDataSource.fetchCreatedBy`); na lista
  /// paginada isso produziria páginas quase vazias.
  List<Event> _matching(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    EventsFilter filter,
  ) {
    return snapshot.docs
        .map((doc) => Event.fromMap(doc.id, doc.data()))
        .where(filter.matches)
        .toList();
  }

  @override
  Future<List<Event>> search(String query) async {
    final normalized = TextNormalizer.normalize(query);
    if (normalized.isEmpty) return const <Event>[];

    // Modalidades cujo nome começa com o termo digitado ("vol" → Vôlei).
    final matchedSports = Sport.values
        .where((s) => TextNormalizer.normalize(s.label).startsWith(normalized))
        .map((s) => s.name)
        .toList();

    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.snapshot
          .where((e) =>
              TextNormalizer.normalize(e.title).contains(normalized) ||
              matchedSports.contains(e.sport.name))
          .toList();
    }

    // Duas consultas em paralelo: prefixo do título + modalidades.
    final snapshots = await Future.wait(
      <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _remote.searchByTitlePrefix(query.trim().toLowerCase()),
        if (matchedSports.isNotEmpty) _remote.searchBySports(matchedSports),
      ],
    );

    final byId = <String, Event>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        byId[doc.id] = Event.fromMap(doc.id, doc.data());
      }
    }
    final results = byId.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return results;
  }

  @override
  Future<Event?> getById(String id) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.getById(id);
    }
    final doc = await _remote.fetchById(id);
    final data = doc.data();
    if (data == null) return null;
    return Event.fromMap(doc.id, data);
  }

  @override
  Future<Event> joinEvent(String eventId, UserSummary user) async {
    if (!kUseFirebaseRepos || _remote == null) {
      final store = InMemoryEventsStore.instance;
      final current = store.getById(eventId);
      if (current == null) {
        throw StateError('Evento $eventId não encontrado');
      }
      if (current.isFull) throw const EventFullException();
      return store.join(eventId, user);
    }

    // Firestore: a transação do datasource valida vagas e registra o
    // UserSummary real do usuário autenticado atomicamente (RN-05).
    await _remote.join(eventId, user.toMap());

    // Re-fetch para retornar o estado atualizado.
    final updated = await _remote.fetchById(eventId);
    return Event.fromMap(updated.id, updated.data()!);
  }

  @override
  Future<Event> createEvent(Event draft) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.add(draft);
    }
    final docRef = await _remote.create(draft.toMap());
    // Retorna o evento com o ID gerado pelo Firestore.
    return Event(
      id: docRef.id,
      title: draft.title,
      sport: draft.sport,
      location: draft.location,
      coordinates: draft.coordinates,
      dateTime: draft.dateTime,
      durationMinutes: draft.durationMinutes,
      skillLevel: draft.skillLevel,
      totalSpots: draft.totalSpots,
      remainingSpots: draft.remainingSpots,
      bannerUrl: draft.bannerUrl,
      creator: draft.creator,
      description: draft.description,
      participants: draft.participants,
    );
  }
}

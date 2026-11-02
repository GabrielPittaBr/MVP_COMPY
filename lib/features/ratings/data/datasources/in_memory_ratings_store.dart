import 'dart:async';

import '../../../../shared/models/event_status.dart';
import '../../../events/data/datasources/in_memory_events_store.dart';
import '../../../notifications/data/datasources/in_memory_notifications_store.dart';
import '../../domain/entities/event_rating_submission.dart';
import '../../domain/entities/rating_summary.dart';
import '../../domain/repositories/ratings_repository.dart';

/// Avaliações do modo mock. Faz o papel da callable: confere o mesmo que o
/// servidor confere, marca o `ratedBy` no store de eventos (para o detalhe
/// passar a mostrar "Você já avaliou") e soma os agregados das médias.
class InMemoryRatingsStore {
  InMemoryRatingsStore._();

  static final InMemoryRatingsStore instance = InMemoryRatingsStore._();

  /// Notas que já existiam antes do app abrir: as 12 do perfil mock (média
  /// 4,8), que o `MockProfile` mostrava fixas antes da tarefa 14.
  static final Map<String, Map<int, int>> _seed = <String, Map<int, int>>{
    'user_u_joao': <int, int>{5: 10, 4: 2},
  };

  final List<EventRatingSubmission> _submissions = <EventRatingSubmission>[];

  /// Contagem por estrela de cada alvo (`{tipo}_{id}`), como em
  /// `ratingSummaries`.
  final Map<String, Map<int, int>> _starCounts = <String, Map<int, int>>{
    for (final entry in _seed.entries) entry.key: Map<int, int>.of(entry.value),
  };
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<EventRatingSubmission> get submissions =>
      List<EventRatingSubmission>.unmodifiable(_submissions);

  RatingSummary summaryOf(RatingTarget target) {
    final counts = _starCounts[_key(target.type, target.id)];
    if (counts == null) return RatingSummary.empty;
    var count = 0;
    var sum = 0;
    counts.forEach((stars, n) {
      count += n;
      sum += stars * n;
    });
    return RatingSummary.fromAggregate(
      count: count,
      sum: sum,
      starCounts: counts,
    );
  }

  Stream<RatingSummary> watchSummary(RatingTarget target) async* {
    yield summaryOf(target);
    yield* _changes.stream.map((_) => summaryOf(target));
  }

  void submit(EventRatingSubmission submission, {required DateTime now}) {
    final events = InMemoryEventsStore.instance;
    final event = events.getById(submission.eventId);
    if (event == null) {
      throw StateError('Evento ${submission.eventId} não encontrado');
    }
    if (event.statusAt(now) != EventStatus.ended) {
      throw const RatingEventNotEndedException();
    }
    if (!event.participantIds.contains(submission.raterId)) {
      throw const RatingNotParticipantException();
    }
    if (event.hasRated(submission.raterId)) {
      throw const RatingAlreadySubmittedException();
    }
    _submissions.add(submission);
    final eventRating = submission.event;
    if (eventRating?.stars case final stars?) {
      _add(RatingTargetType.event, event.id, stars);
    }
    final placeId = event.placeId;
    if (placeId != null && submission.place?.stars != null) {
      _add(RatingTargetType.place, placeId, submission.place!.stars!);
    }
    for (final participant in submission.participants) {
      if (participant.draft.stars case final stars?) {
        _add(RatingTargetType.user, participant.uid, stars);
      }
    }
    events.markRated(submission.eventId, submission.raterId);
    InMemoryNotificationsStore.instance
        .complete(submission.raterId, submission.eventId, at: now);
    _changes.add(null);
  }

  void _add(RatingTargetType type, String id, int stars) {
    final counts = _starCounts.putIfAbsent(_key(type, id), () => <int, int>{});
    counts[stars] = (counts[stars] ?? 0) + 1;
  }

  static String _key(RatingTargetType type, String id) => '${type.name}_$id';
}

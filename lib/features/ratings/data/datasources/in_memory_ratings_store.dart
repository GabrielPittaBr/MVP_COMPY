import '../../../../shared/models/event_status.dart';
import '../../../events/data/datasources/in_memory_events_store.dart';
import '../../../notifications/data/datasources/in_memory_notifications_store.dart';
import '../../domain/entities/event_rating_submission.dart';
import '../../domain/repositories/ratings_repository.dart';

/// Avaliações do modo mock. Faz o papel da callable: confere o mesmo que o
/// servidor confere e marca o `ratedBy` no store de eventos, para o detalhe
/// passar a mostrar "Você já avaliou".
class InMemoryRatingsStore {
  InMemoryRatingsStore._();

  static final InMemoryRatingsStore instance = InMemoryRatingsStore._();

  final List<EventRatingSubmission> _submissions = <EventRatingSubmission>[];

  List<EventRatingSubmission> get submissions =>
      List<EventRatingSubmission>.unmodifiable(_submissions);

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
    events.markRated(submission.eventId, submission.raterId);
    InMemoryNotificationsStore.instance
        .complete(submission.raterId, submission.eventId, at: now);
  }
}

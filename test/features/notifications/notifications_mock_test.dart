import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/data/datasources/in_memory_events_store.dart';
import 'package:mvp_compy/features/notifications/data/datasources/in_memory_notifications_store.dart';
import 'package:mvp_compy/features/ratings/data/repositories/ratings_repository_impl.dart';
import 'package:mvp_compy/features/ratings/domain/entities/event_rating_submission.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_draft.dart';

/// No mock, o store de eventos faz o papel do gatilho `onEventEnded` e o de
/// avaliações, o da callable que marca "Avaliado".
void main() {
  final notificacoes = InMemoryNotificationsStore.instance;
  final eventos = InMemoryEventsStore.instance;

  test('o evento encerrado das fixtures já tem a notificação do João', () {
    final doJoao = notificacoes.of('u_joao');
    expect(doJoao.map((n) => n.id), contains('eventEnded_evt_006'));
    expect(
      doJoao.firstWhere((n) => n.id == 'eventEnded_evt_006').isRead,
      isFalse,
    );
  });

  test('encerrar à mão avisa cada participante; a do criador vem lida', () {
    // `evt_005` é o evento ao vivo, criado pelo Hércules, com o João.
    final aoVivo = eventos.getById('evt_005')!;
    final fim = DateTime.now();

    eventos.end('evt_005', at: fim);

    for (final uid in aoVivo.participantIds) {
      final n =
          notificacoes.of(uid).firstWhere((n) => n.id == 'eventEnded_evt_005');
      expect(n.isRead, uid == aoVivo.creator.id, reason: uid);
      expect(n.endedAutomatically, isFalse);
    }
  });

  test('avaliar marca a notificação como "Avaliado" e lida', () async {
    final fim = DateTime.now();
    await RatingsRepositoryImpl(null, clock: () => fim).submit(
      const EventRatingSubmission(
        eventId: 'evt_006',
        raterId: 'u_joao',
        event: RatingDraft(stars: 4),
      ),
    );

    final n = notificacoes
        .of('u_joao')
        .firstWhere((n) => n.id == 'eventEnded_evt_006');
    expect(n.isCompleted, isTrue);
    expect(n.isRead, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/data/datasources/in_memory_events_store.dart';
import 'package:mvp_compy/features/events/data/repositories/events_repository_impl.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/domain/usecases/delete_own_event.dart';
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

  test('excluir o evento avisa todos menos o Organizador, com o motivo',
      () async {
    // `evt_003` é agendado e criado pelo João.
    final agendado = eventos.getById('evt_003')!;
    final excluir = DeleteOwnEvent(EventsRepositoryImpl(null));

    await excluir('evt_003', reason: '  Quadra fechada.  ');

    expect(eventos.getById('evt_003'), isNull);
    expect(notificacoes.of('u_joao').map((n) => n.id),
        isNot(contains('eventCancelled_evt_003')));
    for (final uid in agendado.participantIds.where((id) => id != 'u_joao')) {
      final n = notificacoes
          .of(uid)
          .firstWhere((n) => n.id == 'eventCancelled_evt_003');
      expect(n.cancelledByOrganizer, isTrue, reason: uid);
      expect(n.reason, 'Quadra fechada.');
    }

    // Repetir não falha nem duplica o aviso.
    await excluir('evt_003');
    final outro = agendado.participantIds.firstWhere((id) => id != 'u_joao');
    expect(
      notificacoes.of(outro).where((n) => n.id == 'eventCancelled_evt_003'),
      hasLength(1),
    );
  });

  test('evento encerrado não é excluído', () {
    expect(
      () => EventsRepositoryImpl(null).deleteOwnEvent('evt_006'),
      throwsA(isA<EventAlreadyEndedException>()),
    );
    expect(eventos.getById('evt_006'), isNotNull);
  });
}

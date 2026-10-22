import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/events/data/datasources/in_memory_events_store.dart';
import 'package:mvp_compy/features/ratings/data/repositories/ratings_repository_impl.dart';
import 'package:mvp_compy/features/ratings/domain/entities/event_rating_submission.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_draft.dart';
import 'package:mvp_compy/features/ratings/domain/repositories/ratings_repository.dart';
import 'package:mvp_compy/shared/widgets/star_rating.dart';

void main() {
  group('RatingsRepositoryImpl (mock)', () {
    // `evt_006` é o evento encerrado ontem das fixtures, com o João
    // (usuário do mock) participando e ainda sem avaliação.
    final repo = RatingsRepositoryImpl(null);
    const doJoao = EventRatingSubmission(
      eventId: 'evt_006',
      raterId: 'u_joao',
      event: RatingDraft(stars: 5),
    );

    test('registra a avaliação e marca o ratedBy do evento', () async {
      await repo.submit(doJoao);

      expect(
        InMemoryEventsStore.instance.getById('evt_006')!.ratedBy,
        contains('u_joao'),
      );
    });

    test('a segunda avaliação do mesmo evento é recusada', () {
      expect(
        () => repo.submit(doJoao),
        throwsA(isA<RatingAlreadySubmittedException>()),
      );
    });

    test('evento ainda acontecendo não aceita avaliação', () {
      expect(
        () => repo.submit(
          const EventRatingSubmission(
            eventId: 'evt_005',
            raterId: 'u_joao',
            event: RatingDraft(stars: 4),
          ),
        ),
        throwsA(isA<RatingEventNotEndedException>()),
      );
    });

    test('quem não participou não avalia', () {
      expect(
        () => repo.submit(
          const EventRatingSubmission(
            eventId: 'evt_006',
            raterId: 'u_visitante',
            event: RatingDraft(stars: 4),
          ),
        ),
        throwsA(isA<RatingNotParticipantException>()),
      );
    });
  });

  testWidgets('estrela de entrada tem alvo de 48px e diz "N de 5 estrelas"',
      (tester) async {
    final handle = tester.ensureSemantics();
    int? escolhida;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StarRating(
            value: null,
            size: 30,
            onChanged: (value) => escolhida = value,
          ),
        ),
      ),
    ));

    final estrela = find.byKey(const ValueKey<String>('star-3'));
    final tamanho = tester.getSize(estrela);
    expect(tamanho.width, greaterThanOrEqualTo(48));
    expect(tamanho.height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(AppStrings.ratingStarsSemantics(3)),
      findsOneWidget,
    );

    await tester.tap(estrela);
    expect(escolhida, 3);
    handle.dispose();
  });
}

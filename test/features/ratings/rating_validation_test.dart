import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/ratings/domain/entities/event_rating_submission.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_draft.dart';
import 'package:mvp_compy/features/ratings/domain/rating_validation.dart';

void main() {
  group('RatingValidation.check', () {
    test('evento e local exigem estrelas', () {
      expect(
        RatingValidation.check(const RatingDraft()),
        RatingIssue.missingStars,
      );
    });

    test('participante sem estrelas só não é avaliado', () {
      expect(
        RatingValidation.check(const RatingDraft(), required: false),
        isNull,
      );
    });

    test('comentário sem estrelas não vale, nem no participante', () {
      expect(
        RatingValidation.check(
          const RatingDraft(comment: 'chegou atrasado'),
          required: false,
        ),
        RatingIssue.commentWithoutStars,
      );
    });

    test('abaixo de 3, o motivo é obrigatório', () {
      for (final stars in <int>[1, 2]) {
        expect(
          RatingValidation.check(RatingDraft(stars: stars)),
          RatingIssue.reasonRequired,
          reason: '$stars estrelas',
        );
        expect(
          RatingValidation.check(RatingDraft(stars: stars, comment: '   ')),
          RatingIssue.reasonRequired,
          reason: 'só espaços não é motivo',
        );
        expect(
          RatingValidation.check(
            RatingDraft(stars: stars, comment: 'Quadra alagada'),
          ),
          isNull,
        );
      }
    });

    test('3 estrelas ou mais dispensam comentário', () {
      for (final stars in <int>[3, 4, 5]) {
        expect(RatingValidation.check(RatingDraft(stars: stars)), isNull);
      }
    });

    test('comentário passa de 500 caracteres depois de aparado', () {
      expect(
        RatingValidation.check(RatingDraft(stars: 5, comment: 'x' * 501)),
        RatingIssue.commentTooLong,
      );
      expect(
        RatingValidation.check(
          RatingDraft(stars: 5, comment: '  ${'x' * 500}  '),
        ),
        isNull,
      );
    });
  });

  group('EventRatingSubmission.toPayload', () {
    test('participante manda evento e local, com o comentário aparado', () {
      const submission = EventRatingSubmission(
        eventId: 'evt_1',
        raterId: 'u_1',
        event: RatingDraft(stars: 2, comment: '  Começou tarde  '),
        place: RatingDraft(stars: 5, comment: '   '),
      );

      expect(submission.toPayload(), <String, Object?>{
        'eventId': 'evt_1',
        'event': <String, Object?>{'stars': 2, 'comment': 'Começou tarde'},
        'place': <String, Object?>{'stars': 5},
        'participants': <Object?>[],
      });
    });

    test('criador não manda a chave do evento', () {
      const submission = EventRatingSubmission(
        eventId: 'evt_1',
        raterId: 'u_dono',
        place: RatingDraft(stars: 4),
      );

      expect(submission.toPayload().containsKey('event'), isFalse);
      expect(submission.toPayload().containsKey('raterId'), isFalse);
    });

    test('participante sem estrelas fica de fora', () {
      const submission = EventRatingSubmission(
        eventId: 'evt_1',
        raterId: 'u_1',
        event: RatingDraft(stars: 5),
        participants: <ParticipantRating>[
          ParticipantRating(uid: 'u_2', draft: RatingDraft(stars: 4)),
          ParticipantRating(uid: 'u_3', draft: RatingDraft()),
        ],
      );

      expect(submission.toPayload()['participants'], <Object?>[
        <String, Object?>{'uid': 'u_2', 'stars': 4},
      ]);
    });
  });
}

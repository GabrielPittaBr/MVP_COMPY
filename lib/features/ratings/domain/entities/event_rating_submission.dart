import 'package:equatable/equatable.dart';

import 'rating_draft.dart';

/// Nota dada a um participante (passo "Quem jogou com você").
class ParticipantRating extends Equatable {
  const ParticipantRating({required this.uid, required this.draft});

  final String uid;
  final RatingDraft draft;

  @override
  List<Object?> get props => <Object?>[uid, draft];
}

/// Tudo o que um Usuário avalia de um evento encerrado, enviado de uma vez.
///
/// [event] fica nulo para o criador, que não avalia o próprio evento (D14);
/// [place] fica nulo no evento legado sem Local Esportivo.
class EventRatingSubmission extends Equatable {
  const EventRatingSubmission({
    required this.eventId,
    required this.raterId,
    this.event,
    this.place,
    this.participants = const <ParticipantRating>[],
  });

  final String eventId;

  /// Quem avalia. A callable descobre pelo token; o mock precisa dele.
  final String raterId;
  final RatingDraft? event;
  final RatingDraft? place;
  final List<ParticipantRating> participants;

  /// Payload da callable `submitEventRatings`: só as notas, com o comentário
  /// aparado e omitido quando vazio. Participante sem estrelas não é
  /// avaliado e fica de fora.
  Map<String, Object?> toPayload() => <String, Object?>{
        'eventId': eventId,
        if (event != null) 'event': _rating(event!),
        if (place != null) 'place': _rating(place!),
        'participants': <Map<String, Object?>>[
          for (final p in participants)
            if (p.draft.stars != null)
              <String, Object?>{
                'uid': p.uid,
                ..._rating(p.draft),
              },
        ],
      };

  static Map<String, Object?> _rating(RatingDraft draft) => <String, Object?>{
        'stars': draft.stars,
        if (draft.trimmedComment.isNotEmpty) 'comment': draft.trimmedComment,
      };

  @override
  List<Object?> get props =>
      <Object?>[eventId, raterId, event, place, participants];
}

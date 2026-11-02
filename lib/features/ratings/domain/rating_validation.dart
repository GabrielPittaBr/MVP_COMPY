import 'entities/rating_draft.dart';

/// Teto do comentário, o mesmo da callable `submitEventRatings`.
const int kRatingCommentMaxLength = 500;

/// Abaixo desta nota o comentário vira obrigatório (D12): quem dá nota
/// baixa conta o motivo.
const int kRatingReasonRequiredBelow = 3;

/// O que impede uma nota de seguir.
enum RatingIssue {
  /// Evento e local exigem nota.
  missingStars,

  /// Comentário sem estrelas. A tela não deixa (o campo fica travado), mas a
  /// regra vale para qualquer origem.
  commentWithoutStars,

  /// Nota abaixo de [kRatingReasonRequiredBelow] sem comentário.
  reasonRequired,

  /// Comentário maior que [kRatingCommentMaxLength].
  commentTooLong,
}

/// Validação pura das notas — a mesma que a callable repete no servidor.
abstract final class RatingValidation {
  /// Primeiro problema de [draft], ou `null` se ela pode seguir.
  ///
  /// [required] é `true` para o evento e o local. Para um participante a nota
  /// é opcional: sem estrelas, ele só não é avaliado.
  static RatingIssue? check(RatingDraft draft, {bool required = true}) {
    final comment = draft.trimmedComment;
    final stars = draft.stars;
    if (stars == null) {
      if (comment.isNotEmpty) return RatingIssue.commentWithoutStars;
      return required ? RatingIssue.missingStars : null;
    }
    if (comment.length > kRatingCommentMaxLength) {
      return RatingIssue.commentTooLong;
    }
    if (stars < kRatingReasonRequiredBelow && comment.isEmpty) {
      return RatingIssue.reasonRequired;
    }
    return null;
  }

  static bool isValid(RatingDraft draft, {bool required = true}) =>
      check(draft, required: required) == null;
}

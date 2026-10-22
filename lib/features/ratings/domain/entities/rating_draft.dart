import 'package:equatable/equatable.dart';

/// Nota em preenchimento para um alvo (evento, local ou participante).
///
/// [stars] nulo = ainda sem nota. O comentário é guardado como digitado; a
/// validação e o envio usam a versão aparada.
class RatingDraft extends Equatable {
  const RatingDraft({this.stars, this.comment = ''});

  final int? stars;
  final String comment;

  String get trimmedComment => comment.trim();

  /// Nada preenchido — fechar o fluxo não perde nada.
  bool get isEmpty => stars == null && trimmedComment.isEmpty;

  RatingDraft withStars(int stars) =>
      RatingDraft(stars: stars, comment: comment);

  RatingDraft withComment(String comment) =>
      RatingDraft(stars: stars, comment: comment);

  @override
  List<Object?> get props => <Object?>[stars, comment];
}

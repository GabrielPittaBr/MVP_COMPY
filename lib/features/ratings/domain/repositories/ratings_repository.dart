import '../entities/event_rating_submission.dart';
import '../entities/rating_summary.dart';

abstract interface class RatingsRepository {
  /// Envia as notas de um evento encerrado. No Firestore, quem grava é a
  /// callable `submitEventRatings`, numa transação: `ratings` é fechada ao
  /// cliente (D13).
  ///
  /// Lança as exceções abaixo, já traduzidas para o domínio.
  Future<void> submit(EventRatingSubmission submission);

  /// Média e distribuição de um alvo, em tempo real. Alvo sem nota nenhuma
  /// emite [RatingSummary.empty].
  Stream<RatingSummary> watchSummary(RatingTarget target);
}

/// Quem chamou já avaliou este evento.
class RatingAlreadySubmittedException implements Exception {
  const RatingAlreadySubmittedException();
}

/// O evento ainda não terminou.
class RatingEventNotEndedException implements Exception {
  const RatingEventNotEndedException();
}

/// Quem chamou não participou do evento.
class RatingNotParticipantException implements Exception {
  const RatingNotParticipantException();
}

/// Sem conexão para falar com a callable.
class RatingOfflineException implements Exception {
  const RatingOfflineException();
}

/// Qualquer outra falha no envio.
class RatingSubmitException implements Exception {
  const RatingSubmitException([this.cause]);
  final Object? cause;
}

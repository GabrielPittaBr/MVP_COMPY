import '../repositories/events_repository.dart';

/// Teto do motivo, o mesmo da callable `deleteOwnEvent`.
const int kEventDeletionReasonMaxLength = 200;

/// O Organizador exclui o próprio evento antes do Encerramento (#37).
class DeleteOwnEvent {
  const DeleteOwnEvent(this._repository);
  final EventsRepository _repository;

  /// [reason] chega aparado, e vazio vira motivo nenhum, como na callable.
  Future<void> call(String eventId, {String? reason}) {
    final trimmed = reason?.trim() ?? '';
    return _repository.deleteOwnEvent(
      eventId,
      reason: trimmed.isEmpty ? null : trimmed,
    );
  }
}

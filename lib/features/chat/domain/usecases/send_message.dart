import '../repositories/chat_repository.dart';

class SendMessage {
  const SendMessage(this._repository);
  final ChatRepository _repository;

  Future<void> call({
    required String conversationId,
    required String peerId,
    required String text,
    String? placeId,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _repository.sendMessage(
      conversationId: conversationId,
      peerId: peerId,
      text: trimmed,
      placeId: placeId,
    );
  }
}

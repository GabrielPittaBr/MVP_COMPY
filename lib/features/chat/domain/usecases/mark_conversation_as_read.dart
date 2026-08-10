import '../repositories/chat_repository.dart';

/// Zera o contador de não-lidas do usuário corrente numa conversa.
class MarkConversationAsRead {
  const MarkConversationAsRead(this._repository);
  final ChatRepository _repository;

  Future<void> call(String conversationId) =>
      _repository.markAsRead(conversationId);
}

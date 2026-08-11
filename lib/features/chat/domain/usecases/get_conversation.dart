import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

/// Uma conversa avulsa, pelo id — `null` quando ela não existe ou o usuário
/// não participa dela.
class GetConversation {
  const GetConversation(this._repository);
  final ChatRepository _repository;

  Future<Conversation?> call(String conversationId, String userId) =>
      _repository.fetchConversation(conversationId, userId);
}

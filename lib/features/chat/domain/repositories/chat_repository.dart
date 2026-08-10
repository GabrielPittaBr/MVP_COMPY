import '../../../../shared/models/paged_result.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class ChatRepository {
  /// Página de conversas de [userId], mais recentes primeiro. Repassar o
  /// [cursor] da página anterior busca a próxima (blocos de [pageSize]).
  Future<PagedResult<Conversation>> fetchConversationsPage(
    String userId, {
    Object? cursor,
    int pageSize,
  });

  /// Uma conversa avulsa, ou `null` quando ela não existe ou [userId] não
  /// participa dela. Usada pela sala quando a conversa não veio na página
  /// já carregada da lista.
  Future<Conversation?> fetchConversation(String conversationId, String userId);

  Stream<List<Message>> watchMessages(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  });
}

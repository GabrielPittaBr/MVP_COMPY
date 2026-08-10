import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/user_summary.dart';
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

  /// Primeira página de conversas, ao vivo — o preview e o contador de
  /// não-lidas mudam sozinhos quando chega mensagem nova.
  Stream<List<Conversation>> watchConversationsFirstPage(
    String userId, {
    int limit,
  });

  /// Uma conversa avulsa, ou `null` quando ela não existe ou [userId] não
  /// participa dela. Usada pela sala quando a conversa não veio na página
  /// já carregada da lista.
  Future<Conversation?> fetchConversation(String conversationId, String userId);

  /// Abre a conversa 1:1 com [peer], criando o documento se ele ainda não
  /// existir, e devolve o id — sempre o mesmo par de uids leva ao mesmo id.
  Future<String> openConversationWith({
    required UserSummary me,
    required UserSummary peer,
  });

  Stream<List<Message>> watchMessages(String conversationId);

  /// Envia [text] e incrementa o contador de não-lidas de [peerId].
  ///
  /// Com [placeId], a mensagem é um local encaminhado: a sala a desenha como
  /// card e [text] vira o resumo que aparece no preview da lista.
  Future<void> sendMessage({
    required String conversationId,
    required String peerId,
    required String text,
    String? placeId,
  });

  /// Zera o contador de não-lidas do usuário corrente nesta conversa.
  Future<void> markAsRead(String conversationId);
}

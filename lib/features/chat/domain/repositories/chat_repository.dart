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
  /// não-lidas mudam sozinhos quando chega mensagem nova. O `cursor` de cada
  /// emissão busca a página seguinte em [fetchConversationsPage], então a
  /// lista não precisa ler a primeira página de novo com `get`.
  Stream<PagedResult<Conversation>> watchConversationsFirstPage(
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

  /// As [limit] mensagens mais recentes, ao vivo, da mais antiga para a mais
  /// recente. O `cursor` aponta a mais antiga da janela e busca as anteriores
  /// em [fetchOlderMessages].
  Stream<PagedResult<Message>> watchRecentMessages(
    String conversationId, {
    int limit,
  });

  /// [pageSize] mensagens anteriores a [cursor], da mais antiga para a mais
  /// recente. Leitura pontual: mensagem antiga não muda.
  Future<PagedResult<Message>> fetchOlderMessages(
    String conversationId, {
    required Object cursor,
    int pageSize,
  });

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

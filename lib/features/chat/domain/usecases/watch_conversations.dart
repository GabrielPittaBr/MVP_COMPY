import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

/// Primeira página de conversas, ao vivo.
///
/// Complementa [GetConversations], que pagina com leitura pontual: o topo da
/// lista precisa reagir sozinho a mensagem recebida, o resto não.
class WatchConversations {
  const WatchConversations(this._repository);
  final ChatRepository _repository;

  Stream<List<Conversation>> call(String userId, {int limit = 10}) =>
      _repository.watchConversationsFirstPage(userId, limit: limit);
}

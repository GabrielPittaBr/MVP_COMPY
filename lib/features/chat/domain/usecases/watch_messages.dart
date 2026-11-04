import '../../../../shared/models/paged_result.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

/// Janela ao vivo com as mensagens mais recentes da conversa.
class WatchMessages {
  const WatchMessages(this._repository);
  final ChatRepository _repository;

  Stream<PagedResult<Message>> call(String conversationId, {int limit = 20}) =>
      _repository.watchRecentMessages(conversationId, limit: limit);
}

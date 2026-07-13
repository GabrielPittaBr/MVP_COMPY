import '../../../../shared/models/paged_result.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

/// Busca uma página de conversas do usuário (mais recentes primeiro).
class GetConversations {
  const GetConversations(this._repository);
  final ChatRepository _repository;

  Future<PagedResult<Conversation>> call(
    String userId, {
    Object? cursor,
    int pageSize = 10,
  }) =>
      _repository.fetchConversationsPage(
        userId,
        cursor: cursor,
        pageSize: pageSize,
      );
}

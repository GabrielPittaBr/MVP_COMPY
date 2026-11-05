import '../../../../shared/models/paged_result.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

/// Página de mensagens anteriores ao [cursor], com leitura pontual.
class GetOlderMessages {
  const GetOlderMessages(this._repository);
  final ChatRepository _repository;

  Future<PagedResult<Message>> call(
    String conversationId, {
    required Object cursor,
    int pageSize = 20,
  }) =>
      _repository.fetchOlderMessages(
        conversationId,
        cursor: cursor,
        pageSize: pageSize,
      );
}

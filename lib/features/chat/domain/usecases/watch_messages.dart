import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class WatchMessages {
  const WatchMessages(this._repository);
  final ChatRepository _repository;

  Stream<List<Message>> call(String conversationId) =>
      _repository.watchMessages(conversationId);
}

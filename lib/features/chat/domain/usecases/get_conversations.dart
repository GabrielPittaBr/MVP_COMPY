import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class GetConversations {
  const GetConversations(this._repository);
  final ChatRepository _repository;

  Stream<List<Conversation>> call() => _repository.watchConversations();
}

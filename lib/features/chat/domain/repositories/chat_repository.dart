import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations();
  Stream<List<Message>> watchMessages(String conversationId);
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  });
}

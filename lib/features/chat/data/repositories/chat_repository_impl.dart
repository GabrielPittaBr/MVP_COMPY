import '../../../../core/constants/app_flags.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/in_memory_chat_store.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote);
  // ignore: unused_field
  final ChatRemoteDataSource _remote;

  @override
  Stream<List<Conversation>> watchConversations() {
    if (!kUseFirebaseRepos) return InMemoryChatStore.instance.watchConversations();
    // TODO(integração): mapear QuerySnapshot -> List<Conversation>.
    return const Stream<List<Conversation>>.empty();
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    if (!kUseFirebaseRepos) {
      return InMemoryChatStore.instance.watchMessages(conversationId);
    }
    return const Stream<List<Message>>.empty();
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    if (!kUseFirebaseRepos) {
      InMemoryChatStore.instance.sendMessage(
        conversationId: conversationId,
        text: text,
      );
      return;
    }
    return _remote.sendMessage(
      conversationId: conversationId,
      senderId: InMemoryChatStore.currentUserId,
      text: text,
    );
  }
}

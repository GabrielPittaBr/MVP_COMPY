import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ChatRemoteDataSource(FirebaseFirestore.instance) : null,
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider)),
);

final getConversationsProvider = Provider<GetConversations>(
  (ref) => GetConversations(ref.watch(chatRepositoryProvider)),
);

final watchMessagesProvider = Provider<WatchMessages>(
  (ref) => WatchMessages(ref.watch(chatRepositoryProvider)),
);

final sendMessageProvider = Provider<SendMessage>(
  (ref) => SendMessage(ref.watch(chatRepositoryProvider)),
);

final conversationsProvider = StreamProvider<List<Conversation>>(
  (ref) => ref.watch(getConversationsProvider).call(),
);

final conversationMessagesProvider =
    StreamProvider.family<List<Message>, String>(
  (ref, conversationId) =>
      ref.watch(watchMessagesProvider).call(conversationId),
);

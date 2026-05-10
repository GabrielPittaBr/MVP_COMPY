import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/in_memory_chat_store.dart';
import '../../domain/entities/conversation.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

/// Tela "5.1 Chat privado" — sala 1:1 com lista em tempo real (RF05).
class ChatRoomPage extends ConsumerWidget {
  const ChatRoomPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider).valueOrNull ?? <Conversation>[];
    Conversation? conversation;
    try {
      conversation = conversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      conversation = null;
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            if (conversation != null)
              CircleAvatar(
                radius: 16,
                backgroundImage: CachedNetworkImageProvider(conversation.peer.avatarUrl),
              ),
            const SizedBox(width: 10),
            Text(conversation?.peer.name ?? 'Conversa'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ref.watch(conversationMessagesProvider(conversationId)).when(
                  data: (messages) => ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return const _DateChip(text: AppStrings.chatToday);
                      final m = messages[i - 1];
                      final isMine = m.senderId == InMemoryChatStore.currentUserId;
                      return MessageBubble(
                        message: m,
                        isMine: isMine,
                        peer: conversation?.peer ??
                            (throw StateError('Conversa $conversationId sem peer')),
                      );
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                ),
          ),
          const Divider(height: 1),
          ChatInputBar(
            onSend: (text) => ref.read(sendMessageProvider).call(
                  conversationId: conversationId,
                  text: text,
                ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/day_label.dart';
import '../../domain/entities/conversation.dart';
import '../models/chat_timeline.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/peer_avatar.dart';

/// Tela "5.1 Chat privado" — sala 1:1 com lista em tempo real (RF05).
///
/// A sala se vira sozinha: se a conversa não estiver na página já carregada
/// da lista, ela lê o documento avulso. Antes o peer saía de um `firstWhere`
/// sobre a lista paginada e a tela estourava quando não achava — bastava
/// abrir a sala com a lista ainda carregando.
class ChatRoomPage extends ConsumerWidget {
  const ChatRoomPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(conversationProvider(conversationId));
    // `valueOrNull` em vez de `when`: enquanto a lista de conversas se
    // atualiza ao lado, o provider volta a "carregando" com o valor anterior
    // preservado — segurar esse valor evita a sala piscar um spinner.
    final conversation = conversationAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            PeerAvatar(peer: conversation?.peer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conversation?.peer.name ?? AppStrings.chatFallbackTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: switch ((conversation, conversationAsync.isLoading)) {
        (final Conversation c, _) => _ChatRoomBody(conversation: c),
        (null, true) => const Center(child: CircularProgressIndicator()),
        // Resolvida e sem conversa: ou não existe, ou o usuário não participa
        // dela — as regras do Firestore recusam a leitura nos dois casos.
        (null, false) => const _CenteredNotice(
            text: AppStrings.chatConversationUnavailable,
          ),
      },
    );
  }
}

class _ChatRoomBody extends ConsumerStatefulWidget {
  const _ChatRoomBody({required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_ChatRoomBody> createState() => _ChatRoomBodyState();
}

class _ChatRoomBodyState extends ConsumerState<_ChatRoomBody> {
  /// Quantas mensagens já foram marcadas como lidas. Serve para não gravar a
  /// cada emissão do stream — só quando chega mensagem nova de fato.
  int _readUpTo = -1;

  @override
  void initState() {
    super.initState();
    // Fora do build: marcar como lida é escrita, não pode sair de um método
    // que o Flutter pode chamar várias vezes por quadro.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
  }

  void _markAsRead() {
    if (!mounted) return;
    ref.read(markConversationAsReadProvider).call(widget.conversation.id);
    // A lista já carregada não é refeita a cada volta da sala: sem espelhar o
    // zero nela, o badge continuaria aceso na tela anterior.
    ref
        .read(paginatedConversationsProvider.notifier)
        .markReadLocally(widget.conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final currentUserId = ref.watch(currentUserIdProvider);

    // Mensagem que chega com a sala aberta já nasce lida.
    ref.listen(conversationMessagesProvider(conversation.id), (_, next) {
      final messages = next.valueOrNull;
      if (messages == null || messages.length <= _readUpTo) return;
      _readUpTo = messages.length;
      if (messages.isNotEmpty && messages.last.senderId != currentUserId) {
        _markAsRead();
      }
    });

    return Column(
      children: <Widget>[
        Expanded(
          child: ref.watch(conversationMessagesProvider(conversation.id)).when(
                data: (messages) {
                  final items = buildChatTimeline(messages);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) => switch (items[i]) {
                      ChatDaySeparator(:final day) =>
                        _DateChip(text: DayLabel.of(day)),
                      ChatMessageItem(:final message) => MessageBubble(
                          message: message,
                          isMine: message.senderId == currentUserId,
                          peer: conversation.peer,
                        ),
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const _CenteredNotice(
                  text: AppStrings.chatConversationUnavailable,
                ),
              ),
        ),
        const Divider(height: 1),
        ChatInputBar(
          onSend: (text) => ref.read(sendMessageProvider).call(
                conversationId: conversation.id,
                peerId: conversation.peer.id,
                text: text,
              ),
        ),
      ],
    );
  }
}

class _CenteredNotice extends StatelessWidget {
  const _CenteredNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
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

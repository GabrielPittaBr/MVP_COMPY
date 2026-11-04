import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/day_label.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/conversation.dart';
import '../models/chat_timeline.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

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
    final peer = conversation == null
        ? null
        : ref.watch(conversationPeerProvider(conversation.peer));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: conversation == null ||
                  conversation.peer.id.isEmpty ||
                  conversation.peer.id == 'unknown'
              ? null
              : () => context.push(
                    AppRoutes.publicProfileFor(conversation.peer.id),
                  ),
          child: Row(
            children: <Widget>[
              UserAvatar(user: peer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  peer?.name ?? AppStrings.chatFallbackTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: switch ((conversation, conversationAsync.isLoading)) {
        (final Conversation c, _) =>
          _ChatRoomBody(conversation: c, peer: peer!),
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
  const _ChatRoomBody({required this.conversation, required this.peer});

  final Conversation conversation;
  final UserSummary peer;

  @override
  ConsumerState<_ChatRoomBody> createState() => _ChatRoomBodyState();
}

class _ChatRoomBodyState extends ConsumerState<_ChatRoomBody> {
  /// Id da última mensagem já tratada como lida. Serve para não gravar a cada
  /// emissão do stream — só quando chega mensagem nova de fato. Por id, e não
  /// pela contagem: a janela ao vivo não cresce quando chega mensagem (a mais
  /// antiga sai dela) e a página antiga cresce a lista sem mensagem nova.
  String? _readUpToId;

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

    final provider = paginatedMessagesProvider(conversation.id);

    // Mensagem que chega com a sala aberta já nasce lida.
    ref.listen(provider, (_, next) {
      final last = next.valueOrNull?.lastOrNull;
      if (last == null || last.id == _readUpToId) return;
      _readUpToId = last.id;
      if (last.senderId != currentUserId) _markAsRead();
    });

    return Column(
      children: <Widget>[
        Expanded(
          child: ref.watch(provider).when(
                data: (messages) {
                  final controller = ref.read(provider.notifier);
                  final items = buildChatTimeline(messages);
                  final hasMore = controller.hasMore;
                  // Invertida: a sala abre no fim da conversa e as páginas
                  // antigas entram no topo sem a tela pular. O fim do scroll
                  // é o topo da tela.
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!controller.loadMoreFailed &&
                          notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200) {
                        controller.loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      // +1 para o indicador de "carregando anteriores".
                      itemCount: items.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return _OlderMessagesStatus(
                            failed: controller.loadMoreFailed,
                            onRetry: controller.loadMore,
                          );
                        }
                        return switch (items[items.length - 1 - i]) {
                          ChatDaySeparator(:final day) =>
                            _DateChip(text: DayLabel.of(day)),
                          ChatMessageItem(:final message) => MessageBubble(
                              message: message,
                              isMine: message.senderId == currentUserId,
                              peer: widget.peer,
                            ),
                        };
                      },
                    ),
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

/// Topo da sala enquanto há mensagens anteriores: spinner durante a busca,
/// ou o "tentar de novo" quando ela falhou.
class _OlderMessagesStatus extends StatelessWidget {
  const _OlderMessagesStatus({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: failed
          ? Column(
              children: <Widget>[
                const Text(AppStrings.chatLoadOlderError),
                TextButton(
                  onPressed: onRetry,
                  child: const Text(AppStrings.commonRetry),
                ),
              ],
            )
          : const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
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

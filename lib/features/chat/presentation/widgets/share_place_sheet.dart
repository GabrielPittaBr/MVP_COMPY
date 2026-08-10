import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conversation.dart';
import '../providers/chat_providers.dart';
import 'peer_avatar.dart';

/// Escolhe para qual conversa o local vai (D11).
///
/// Abre sobre a tela do local; ao enviar, fecha e leva para a sala, onde o
/// local já aparece como última mensagem.
class SharePlaceSheet extends ConsumerStatefulWidget {
  const SharePlaceSheet({required this.placeId, super.key});

  final String placeId;

  /// Abre o seletor. Devolve quando o sheet fecha.
  static Future<void> show(BuildContext context, String placeId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SharePlaceSheet(placeId: placeId),
    );
  }

  @override
  ConsumerState<SharePlaceSheet> createState() => _SharePlaceSheetState();
}

class _SharePlaceSheetState extends ConsumerState<SharePlaceSheet> {
  bool _sending = false;

  Future<void> _send(Conversation conversation) async {
    if (_sending) return;
    setState(() => _sending = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(sendMessageProvider).call(
            conversationId: conversation.id,
            peerId: conversation.peer.id,
            // O texto não é decorativo: é ele que a lista de conversas mostra
            // no preview, onde não há espaço para desenhar o card.
            text: AppStrings.chatForwardedPlace,
            placeId: widget.placeId,
          );

      navigator.pop();
      router.go('${AppRoutes.chat}/${conversation.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.chatShareError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(paginatedConversationsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                AppStrings.chatShareTo,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (_sending) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: conversations.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Text(
                        AppStrings.chatShareNoConversations,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) {
                      final conversation = items[i];
                      return ListTile(
                        onTap: _sending ? null : () => _send(conversation),
                        leading: PeerAvatar(peer: conversation.peer, radius: 24),
                        title: Text(
                          conversation.peer.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          conversation.peer.handle,
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    AppStrings.chatShareError,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onSurfaceMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

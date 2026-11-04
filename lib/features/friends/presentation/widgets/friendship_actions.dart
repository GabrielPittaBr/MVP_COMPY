import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/action_button.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/friendship.dart';
import '../providers/friends_providers.dart';

/// Único caminho das telas até o controller de amizade: confirma antes de
/// desfazer e avisa o resultado. Perfil e lista se comportam igual por
/// passarem os dois por aqui.
Future<void> runFriendshipAction(
  BuildContext context,
  WidgetRef ref, {
  required String peerId,
  required FriendshipAction action,
  Friendship? relation,
}) async {
  if (action == FriendshipAction.remove) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.friendsRemoveTitle),
        content: const Text(AppStrings.friendsRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.friendsRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final success = await ref
      .read(friendshipControllerProvider(peerId).notifier)
      .execute(action, expected: relation);
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(success
            ? AppStrings.friendshipSuccess(action.name)
            : AppStrings.friendsOperationError)));
}

/// Ações do perfil de outra pessoa: amizade e mensagem, lado a lado.
///
/// O botão de amizade segue a relação privada da sessão. A mensagem fica
/// disponível em qualquer estado, inclusive carregando ou com erro, e vira a
/// ação principal quando adicionar ou aceitar não é mais o que falta fazer.
class FriendshipActions extends ConsumerWidget {
  const FriendshipActions({
    required this.peerId,
    required this.onMessage,
    this.messageLoading = false,
    super.key,
  });

  final String peerId;
  final VoidCallback onMessage;
  final bool messageLoading;

  Future<void> _options(
      BuildContext context, WidgetRef ref, Friendship relation) async {
    final accepted = relation.status == FriendshipStatus.accepted;
    final action = await showModalBottomSheet<FriendshipAction>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
                accepted ? Icons.person_remove_outlined : Icons.close_rounded,
                color: accepted ? AppColors.error : AppColors.onSurface),
            title: Text(
                accepted ? AppStrings.friendsRemove : AppStrings.friendsCancel,
                style: TextStyle(
                    color: accepted ? AppColors.error : AppColors.onSurface,
                    fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(sheet,
                accepted ? FriendshipAction.remove : FriendshipAction.cancel),
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    await runFriendshipAction(context, ref,
        peerId: peerId, action: action, relation: relation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final uid = ref.watch(currentUserIdProvider);
    if (uid == peerId) return const SizedBox.shrink();
    final busy = ref.watch(friendshipControllerProvider(peerId)).isLoading;
    void run(FriendshipAction action, Friendship? relation) =>
        runFriendshipAction(context, ref,
            peerId: peerId, action: action, relation: relation);

    final (
      Widget? friendship,
      ActionTone messageTone,
      Widget? footer
    ) = uid == null
        ? (null, ActionTone.filled, null)
        : ref.watch(friendshipWithProvider(peerId)).when(
              loading: () => (
                const ActionButton(
                    label: AppStrings.friendsLoadingState,
                    icon: Icons.person_outline,
                    onPressed: null,
                    tone: ActionTone.tonal,
                    loading: true),
                ActionTone.outlined,
                null,
              ),
              error: (_, __) => (
                ActionButton(
                    label: AppStrings.friendsReload,
                    icon: Icons.refresh_rounded,
                    tone: ActionTone.outlined,
                    onPressed: () => ref.invalidate(friendshipsProvider)),
                ActionTone.filled,
                const Text(AppStrings.friendsLoadError,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceMuted)),
              ),
              data: (relation) {
                if (relation == null) {
                  return (
                    ActionButton(
                        label: AppStrings.friendsAdd,
                        icon: Icons.person_add_alt_1_outlined,
                        loading: busy,
                        onPressed: () => run(FriendshipAction.send, null)),
                    ActionTone.outlined,
                    null,
                  );
                }
                if (relation.status == FriendshipStatus.accepted) {
                  return (
                    ActionButton(
                        label: AppStrings.friendsConfirmed,
                        icon: Icons.how_to_reg_outlined,
                        tone: ActionTone.tonal,
                        loading: busy,
                        onPressed: () => _options(context, ref, relation)),
                    ActionTone.filled,
                    null,
                  );
                }
                // A direção vem do UID da sessão; não depende do nome.
                if (relation.senderId == peerId) {
                  return (
                    ActionButton(
                        label: AppStrings.friendsAccept,
                        icon: Icons.check_rounded,
                        loading: busy,
                        onPressed: () =>
                            run(FriendshipAction.accept, relation)),
                    ActionTone.outlined,
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => run(FriendshipAction.decline, relation),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.onSurfaceMuted),
                        child: const Text(AppStrings.friendsDeclineRequest)),
                  );
                }
                return (
                  ActionButton(
                      label: AppStrings.friendsRequested,
                      icon: Icons.schedule_rounded,
                      tone: ActionTone.tonal,
                      loading: busy,
                      onPressed: () => _options(context, ref, relation)),
                  ActionTone.filled,
                  null,
                );
              },
            );

    final buttons = <Widget>[
      if (friendship != null) friendship,
      ActionButton(
        label: AppStrings.profileMessage,
        icon: Icons.chat_bubble_outline_rounded,
        tone: messageTone,
        loading: messageLoading,
        onPressed: onMessage,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          // ponytail: largura mínima estimada por botão (ícone + rótulo
          // curto), escalada pela fonte do sistema. Abaixo dela os botões
          // empilham em vez de cortar o rótulo; medir o texto real só vale
          // a pena se surgir rótulo bem mais longo.
          final minWidth = 128 * MediaQuery.textScalerOf(context).scale(1);
          final fits = constraints.maxWidth >=
              buttons.length * minWidth + 8 * (buttons.length - 1);
          if (!fits) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  buttons[i],
                ],
              ],
            );
          }
          return Row(children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buttons[i]),
            ],
          ]);
        }),
        if (footer != null) ...[
          const SizedBox(height: 4),
          Center(child: footer),
        ],
      ],
    );
  }
}

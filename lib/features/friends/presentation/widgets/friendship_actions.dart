import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/friendship.dart';
import '../providers/friends_providers.dart';

class FriendshipActions extends ConsumerWidget {
  const FriendshipActions({required this.peerId, super.key});
  final String peerId;

  Future<void> _execute(BuildContext context, WidgetRef ref,
      FriendshipAction action, Friendship? relation) async {
    if (action == FriendshipAction.remove) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text(AppStrings.friendsRemoveTitle),
                content: const Text(AppStrings.friendsRemoveBody),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(AppStrings.commonCancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(AppStrings.friendsRemove)),
                ],
              ));
      if (confirmed != true || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(friendshipControllerProvider(peerId).notifier)
        .execute(action, expected: relation);
    if (!messenger.mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text(success
            ? AppStrings.friendshipSuccess(action.name)
            : AppStrings.friendsOperationError)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null || uid == peerId) return const SizedBox.shrink();
    final state = ref.watch(friendshipWithProvider(peerId));
    final operation = ref.watch(friendshipControllerProvider(peerId));
    final busy = operation.isLoading;
    Widget button(String label, FriendshipAction action, Friendship? relation,
        {bool primary = false}) {
      final callback =
          busy ? null : () => _execute(context, ref, action, relation);
      return primary
          ? FilledButton(onPressed: callback, child: Text(label))
          : TextButton(onPressed: callback, child: Text(label));
    }

    return state.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (_, __) =>
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text(AppStrings.friendsLoadError),
        TextButton(
            onPressed: () => ref.invalidate(friendshipsProvider),
            child: const Text(AppStrings.commonRetry)),
      ]),
      data: (relation) {
        final List<Widget> children;
        if (relation == null) {
          children = [
            button(AppStrings.friendsAdd, FriendshipAction.send, null,
                primary: true)
          ];
        } else if (relation.status == FriendshipStatus.accepted) {
          children = [
            const Text(AppStrings.friendsConfirmed),
            button(AppStrings.friendsRemove, FriendshipAction.remove, relation)
          ];
        } else {
          // A direção vem do UID da sessão; a identidade não depende do nome.
          final received = relation.senderId == peerId;
          children = received
              ? [
                  const Text(AppStrings.friendsRespond),
                  button(AppStrings.friendsAccept, FriendshipAction.accept,
                      relation,
                      primary: true),
                  button(AppStrings.friendsDecline, FriendshipAction.decline,
                      relation),
                ]
              : [
                  const Text(AppStrings.friendsSentState),
                  button(AppStrings.friendsCancel, FriendshipAction.cancel,
                      relation),
                ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children),
          if (busy) const LinearProgressIndicator(minHeight: 2),
        ]);
      },
    );
  }
}

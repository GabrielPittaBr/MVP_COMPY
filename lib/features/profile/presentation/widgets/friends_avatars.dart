import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../friends/domain/entities/friendship.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../providers/profile_providers.dart';

class FriendsSection extends ConsumerWidget {
  const FriendsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GoRouter conserva a aba Perfil no indexedStack quando ela está oculta.
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final uid = ref.watch(currentUserIdProvider);
    return ref.watch(friendshipsProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(AppStrings.profileFriends),
            const Text(AppStrings.friendsLoadError),
            TextButton(
                onPressed: () => ref.invalidate(friendshipsProvider),
                child: const Text(AppStrings.commonRetry)),
          ]),
          data: (relations) {
            final friends = relations
                .where((f) => f.status == FriendshipStatus.accepted)
                .toList();
            final received = relations
                .where((f) =>
                    f.status == FriendshipStatus.pending && f.senderId != uid)
                .length;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                            AppStrings.friendsTab(
                                AppStrings.profileFriends, friends.length),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        TextButton(
                            onPressed: () => context.push(AppRoutes.friends),
                            child: const Text(AppStrings.friendsSeeAll)),
                      ]),
                  if (received > 0)
                    TextButton.icon(
                        onPressed: () =>
                            context.push('${AppRoutes.friends}?tab=1'),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(AppStrings.friendsRequestsCount(received))),
                  if (friends.isEmpty)
                    const Text(AppStrings.friendsEmpty)
                  else
                    FriendsAvatars(
                        userIds: friends
                            .take(6)
                            .map((f) => f.peerOf(uid!))
                            .toList()),
                ]);
          },
        );
  }
}

class FriendsAvatars extends StatelessWidget {
  const FriendsAvatars({required this.userIds, super.key});
  final List<String> userIds;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final uid in userIds.take(6)) _FriendAvatar(uid: uid),
      ]);
}

class _FriendAvatar extends ConsumerWidget {
  const _FriendAvatar({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(publicUserSummaryProvider(uid)).valueOrNull;
    return Tooltip(
        message: person?.name ?? AppStrings.friendsMissingProfile,
        child: InkWell(
          onTap: person == null
              ? null
              : () => context.push(AppRoutes.publicProfileFor(uid)),
          customBorder: const CircleBorder(),
          child: UserAvatar(user: person, radius: 24),
        ));
  }
}

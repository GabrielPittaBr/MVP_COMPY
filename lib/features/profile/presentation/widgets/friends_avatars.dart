import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../friends/domain/entities/friendship.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../providers/profile_providers.dart';

/// Seção "Amigos" do perfil próprio: contagem, aviso de pedidos recebidos e
/// uma fileira curta de amigos. Lê só o grafo privado da sessão.
class FriendsSection extends ConsumerWidget {
  const FriendsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GoRouter conserva a aba Perfil no indexedStack quando ela está oculta.
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final uid = ref.watch(currentUserIdProvider);
    final relations = ref.watch(friendshipsProvider);
    final friends = [
      for (final f in relations.valueOrNull ?? const <Friendship>[])
        if (f.status == FriendshipStatus.accepted) f
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Wrap e não Row: com fonte ampliada o "Ver todos" desce de linha em
      // vez de espremer o título.
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(TextSpan(
                text: AppStrings.profileFriends,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface),
                children: [
                  if (relations.hasValue)
                    TextSpan(
                        text: '  ${friends.length}',
                        style:
                            const TextStyle(color: AppColors.onSurfaceMuted)),
                ])),
            TextButton(
              onPressed: () => context.push(AppRoutes.friends),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceMuted,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 12, right: 4)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(AppStrings.friendsSeeAll)),
                Icon(Icons.chevron_right_rounded, size: 20),
              ]),
            ),
          ]),
      const SizedBox(height: 8),
      relations.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, __) => Row(children: [
          const Expanded(
              child: Text(AppStrings.friendsLoadError,
                  style: TextStyle(color: AppColors.onSurfaceMuted))),
          TextButton(
              onPressed: () => ref.invalidate(friendshipsProvider),
              child: const Text(AppStrings.commonRetry)),
        ]),
        data: (relations) {
          final received = relations
              .where((f) =>
                  f.status == FriendshipStatus.pending && f.senderId != uid)
              .length;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (received > 0) ...[
                  _Tappable(
                    color: AppColors.primary.withAlpha(20),
                    onTap: () => context.push('${AppRoutes.friends}?tab=1'),
                    leading: const Icon(Icons.person_add_alt_1_outlined,
                        color: AppColors.primary),
                    child: Text(AppStrings.friendsRequestsCount(received),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (friends.isEmpty)
                  _Tappable(
                    color: AppColors.surfaceCard,
                    onTap: () => context.push(AppRoutes.friendsSearch),
                    leading: const Icon(Icons.group_outlined,
                        color: AppColors.onSurfaceMuted),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.friendsEmpty),
                          SizedBox(height: 2),
                          Text(AppStrings.friendsFindPeople,
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  )
                else
                  FriendsAvatars(
                      userIds:
                          friends.take(6).map((f) => f.peerOf(uid!)).toList()),
              ]);
        },
      ),
    ]);
  }
}

/// Faixa arredondada inteira tocável, com ícone à esquerda e seta à direita.
class _Tappable extends StatelessWidget {
  const _Tappable(
      {required this.color,
      required this.onTap,
      required this.leading,
      required this.child});
  final Color color;
  final VoidCallback onTap;
  final Widget leading;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: child),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceMuted),
            ]),
          ),
        ),
      );
}

/// Fileira de até seis amigos com foto e primeiro nome; cada um abre o
/// perfil. Só os visíveis assinam o resumo público.
class FriendsAvatars extends StatelessWidget {
  const FriendsAvatars({required this.userIds, super.key});
  final List<String> userIds;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final uid in userIds.take(6)) _FriendAvatar(uid: uid),
        ]),
      );
}

class _FriendAvatar extends ConsumerWidget {
  const _FriendAvatar({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(publicUserSummaryProvider(uid)).valueOrNull;
    return Tooltip(
        message: person == null
            ? AppStrings.friendsMissingProfile
            : '${person.name} ${person.handle}',
        child: InkWell(
          key: ValueKey('friend-preview-$uid'),
          onTap: person == null
              ? null
              : () => context.push(AppRoutes.publicProfileFor(uid)),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                UserAvatar(user: person, radius: 28),
                const SizedBox(height: 6),
                Text(person?.name.split(' ').first ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ));
  }
}

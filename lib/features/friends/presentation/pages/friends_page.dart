import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/action_button.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/open_conversation.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/friendship.dart';
import '../providers/friends_providers.dart';
import '../widgets/friendship_actions.dart';

enum _Tab { friends, received, sent }

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({this.initialTab = 0, super.key});
  final int initialTab;
  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage>
    with SingleTickerProviderStateMixin {
  final _visible = [25, 25, 25];
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _empty(_Tab tab) => switch (tab) {
        _Tab.friends => _EmptyState(
            icon: Icons.group_outlined,
            title: AppStrings.friendsEmptyFriendsTitle,
            hint: AppStrings.friendsEmptyFriendsHint,
            action: ActionButton(
                label: AppStrings.friendsFindPeople,
                icon: Icons.person_search_outlined,
                tone: ActionTone.outlined,
                onPressed: () => context.push(AppRoutes.friendsSearch)),
          ),
        _Tab.received => const _EmptyState(
            icon: Icons.inbox_outlined,
            title: AppStrings.friendsEmptyReceivedTitle,
            hint: AppStrings.friendsEmptyReceivedHint,
          ),
        _Tab.sent => const _EmptyState(
            icon: Icons.outbox_outlined,
            title: AppStrings.friendsEmptySentTitle,
            hint: AppStrings.friendsEmptySentHint,
          ),
      };

  @override
  Widget build(BuildContext context) {
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final relations = ref.watch(friendshipsProvider);
    final uid = ref.watch(currentUserIdProvider);
    final items = [...?relations.valueOrNull]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    final groups = [
      items.where((f) => f.status == FriendshipStatus.accepted).toList(),
      items
          .where(
              (f) => f.status == FriendshipStatus.pending && f.senderId != uid)
          .toList(),
      items
          .where(
              (f) => f.status == FriendshipStatus.pending && f.senderId == uid)
          .toList(),
    ];
    return Scaffold(
      appBar: AppBar(
          title: const Text(AppStrings.friendsTitle),
          actions: [
            IconButton(
                tooltip: AppStrings.friendsFind,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () => context.push(AppRoutes.friendsSearch)),
          ],
          // Centralizadas cabem em 360 dp sem o recuo inicial do Material 3;
          // em telas mais estreitas ou fonte ampliada, rolam.
          bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(
                    text: AppStrings.friendsTab(
                        AppStrings.profileFriends, groups[0].length)),
                Tab(
                    text: AppStrings.friendsTab(
                        AppStrings.friendsReceived, groups[1].length)),
                Tab(
                    text: AppStrings.friendsTab(
                        AppStrings.friendsSent, groups[2].length)),
              ])),
      body: relations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: AppStrings.friendsLoadError,
          action: ActionButton(
              label: AppStrings.commonRetry,
              icon: Icons.refresh_rounded,
              tone: ActionTone.outlined,
              onPressed: () => ref.invalidate(friendshipsProvider)),
        ),
        data: (_) => TabBarView(controller: _tabs, children: [
          for (final tab in _Tab.values)
            if (groups[tab.index].isEmpty)
              _empty(tab)
            else
              ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups[tab.index].take(_visible[tab.index]).length +
                    (groups[tab.index].length > _visible[tab.index] ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(indent: 76, endIndent: 16),
                itemBuilder: (context, i) => i == _visible[tab.index]
                    ? Center(
                        child: TextButton(
                            onPressed: () =>
                                setState(() => _visible[tab.index] += 25),
                            child: const Text(AppStrings.friendsLoadMore)))
                    : _FriendRow(
                        key: ValueKey(groups[tab.index][i].id),
                        relation: groups[tab.index][i],
                        peerId: groups[tab.index][i].peerOf(uid!),
                        tab: tab),
              ),
        ]),
      ),
    );
  }
}

/// Uma pessoa da lista: avatar, nome e @, com as ações da aba ao lado.
/// O toque na linha abre o perfil; as ações passam por
/// [runFriendshipAction], como no perfil.
class _FriendRow extends ConsumerStatefulWidget {
  const _FriendRow(
      {required this.relation,
      required this.peerId,
      required this.tab,
      super.key});
  final Friendship relation;
  final String peerId;
  final _Tab tab;
  @override
  ConsumerState<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends ConsumerState<_FriendRow> {
  bool _opening = false;

  void _run(FriendshipAction action) => runFriendshipAction(context, ref,
      peerId: widget.peerId, action: action, relation: widget.relation);

  Future<void> _message(UserSummary person) async {
    if (_opening) return;
    setState(() => _opening = true);
    await pushConversationWith(context, ref, person);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final uid = widget.peerId;
    final profile = ref.watch(publicUserSummaryProvider(uid));
    final person = profile.valueOrNull;
    final busy = ref.watch(friendshipControllerProvider(uid)).isLoading;
    const spinner = Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
            dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)));

    final Widget? trailing = switch (widget.tab) {
      _Tab.received => null,
      _ when busy => spinner,
      _Tab.friends => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: AppStrings.profileMessage,
              icon: _opening
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_bubble_outline_rounded),
              color: AppColors.primary,
              onPressed:
                  person == null || _opening ? null : () => _message(person)),
          PopupMenuButton<FriendshipAction>(
            tooltip: AppStrings.friendsMoreOptions,
            icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceMuted),
            onSelected: _run,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: FriendshipAction.remove,
                child: Row(children: [
                  Icon(Icons.person_remove_outlined,
                      size: 20, color: AppColors.onSurfaceMuted),
                  SizedBox(width: 12),
                  // Com fonte ampliada o menu bate na largura máxima.
                  Flexible(child: Text(AppStrings.friendsRemove)),
                ]),
              ),
            ],
          ),
        ]),
      // Ícone e não texto: largura fixa, que não cresce com a fonte.
      _Tab.sent => IconButton(
          tooltip: AppStrings.friendsCancel,
          icon: const Icon(Icons.close_rounded),
          color: AppColors.onSurfaceMuted,
          onPressed: () => _run(FriendshipAction.cancel)),
    };

    return InkWell(
      key: ValueKey('friend-profile-$uid'),
      onTap: person == null
          ? null
          : () => context.push(AppRoutes.publicProfileFor(uid)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
            crossAxisAlignment: widget.tab == _Tab.received
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              UserAvatar(user: person, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        person?.name ??
                            (profile.isLoading
                                ? AppStrings.friendsLoadingProfile
                                : AppStrings.friendsMissingProfile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (person != null)
                      Text(person.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: AppColors.onSurfaceMuted)),
                    if (widget.tab == _Tab.sent) ...[
                      const SizedBox(height: 2),
                      const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: AppColors.warningText),
                        SizedBox(width: 4),
                        Flexible(
                            child: Text(AppStrings.friendsPending,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warningText))),
                      ]),
                    ],
                    if (profile.hasError)
                      TextButton(
                          onPressed: () =>
                              ref.invalidate(publicUserSummaryProvider(uid)),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact),
                          child: const Text(AppStrings.commonRetry)),
                    if (widget.tab == _Tab.received) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ActionButton(
                            label: AppStrings.friendsAccept,
                            icon: Icons.check_rounded,
                            compact: true,
                            loading: busy,
                            onPressed: () => _run(FriendshipAction.accept)),
                        ActionButton(
                            label: AppStrings.friendsDecline,
                            icon: Icons.close_rounded,
                            tone: ActionTone.tonal,
                            compact: true,
                            onPressed: busy
                                ? null
                                : () => _run(FriendshipAction.decline)),
                      ]),
                    ],
                  ])),
              if (trailing != null) trailing,
            ]),
      ),
    );
  }
}

/// Estado vazio ou de erro de uma aba: ícone, título, dica e ação opcional.
class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, this.hint, this.action});
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onSurfaceMuted)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

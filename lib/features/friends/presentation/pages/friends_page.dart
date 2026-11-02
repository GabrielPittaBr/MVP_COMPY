import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/friendship.dart';
import '../providers/friends_providers.dart';
import '../widgets/friendship_actions.dart';

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
          bottom: TabBar(controller: _tabs, isScrollable: true, tabs: [
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
        error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(AppStrings.friendsLoadError),
          TextButton(
              onPressed: () => ref.invalidate(friendshipsProvider),
              child: const Text(AppStrings.commonRetry)),
        ])),
        data: (_) => TabBarView(controller: _tabs, children: [
          for (var tab = 0; tab < 3; tab++)
            groups[tab].isEmpty
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(AppStrings.friendsEmptyList,
                            textAlign: TextAlign.center)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groups[tab].take(_visible[tab]).length +
                        (groups[tab].length > _visible[tab] ? 1 : 0),
                    itemBuilder: (context, i) => i == _visible[tab]
                        ? TextButton(
                            onPressed: () =>
                                setState(() => _visible[tab] += 25),
                            child: const Text(AppStrings.friendsLoadMore))
                        : _FriendRow(uid: groups[tab][i].peerOf(uid!)),
                  ),
        ]),
      ),
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém compatibilidade com Flutter 3.22; valuesOf chegou depois.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final profile = ref.watch(publicUserSummaryProvider(uid));
    final person = profile.valueOrNull;
    return Card(
      color: AppColors.surface,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: ValueKey('friend-profile-$uid'),
                onTap: person == null
                    ? null
                    : () => context.push(AppRoutes.publicProfileFor(uid)),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      UserAvatar(user: person, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                person?.name ??
                                    (profile.isLoading
                                        ? AppStrings.friendsLoadingProfile
                                        : AppStrings.friendsMissingProfile),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (person != null)
                              Text(person.handle,
                                  style: const TextStyle(
                                      color: AppColors.onSurfaceMuted)),
                          ])),
                      if (person != null) const Icon(Icons.chevron_right),
                    ])),
              ),
              if (profile.hasError)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () =>
                            ref.invalidate(publicUserSummaryProvider(uid)),
                        child: const Text(AppStrings.commonRetry))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FriendshipActions(peerId: uid)),
            ],
          )),
    );
  }
}

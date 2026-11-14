import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/safety_providers.dart';
import '../widgets/safety_menu.dart';

/// Pessoas bloqueadas (Configurações → Privacidade), com o desbloqueio.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Set<String>> blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsBlocked)),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text(AppStrings.blockError)),
        data: (Set<String> uids) => uids.isEmpty
            ? const Center(
                child: Text(
                  AppStrings.blockedListEmpty,
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                ),
              )
            : ListView(
                children: <Widget>[
                  for (final String uid in uids) _BlockedTile(uid: uid),
                ],
              ),
      ),
    );
  }
}

class _BlockedTile extends ConsumerWidget {
  const _BlockedTile({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserSummary?> summary = ref.watch(publicUserSummaryProvider(uid));
    // Perfil que já não existe: a pessoa excluiu a conta.
    final UserSummary? user = summary.valueOrNull;
    final String name = user?.name ?? (summary.isLoading ? '' : AppStrings.blockedDeletedAccount);
    return ListTile(
      leading: UserAvatar(user: user),
      title: Text(name),
      subtitle: user == null || user.handle.isEmpty ? null : Text(user.handle),
      trailing: TextButton(
        onPressed: () => toggleBlock(context, ref, uid: uid, name: name),
        child: const Text(AppStrings.unblockUser),
      ),
    );
  }
}

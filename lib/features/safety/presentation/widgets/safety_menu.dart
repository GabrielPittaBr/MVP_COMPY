import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/report.dart';
import '../providers/safety_providers.dart';
import 'report_sheet.dart';

/// Confirma o bloqueio de [uid] e avisa o resultado. Desbloquear não pede
/// confirmação: é desfazer.
Future<void> toggleBlock(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
  required String name,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool blocked = ref.read(isBlockedProvider(uid));
  if (!blocked) {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.blockConfirmTitle(name)),
        content: const Text(AppStrings.blockConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.blockUser, style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }
  final bool ok = await ref.read(safetyActionsProvider).setBlocked(uid, blocked: !blocked);
  messenger.showSnackBar(
    SnackBar(
      content: Text(!ok
          ? AppStrings.blockError
          : blocked
              ? AppStrings.unblockDone
              : AppStrings.blockDone),
      backgroundColor: ok ? null : AppColors.error,
    ),
  );
}

enum _SafetyAction { report, block }

/// Menu de três pontos com "Denunciar" e "Bloquear"/"Desbloquear", para o
/// perfil público e a sala de chat.
class UserSafetyMenu extends ConsumerWidget {
  const UserSafetyMenu({required this.uid, required this.name, super.key});

  final String uid;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool blocked = ref.watch(isBlockedProvider(uid));
    return PopupMenuButton<_SafetyAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: AppStrings.friendsMoreOptions,
      onSelected: (_SafetyAction action) => switch (action) {
        _SafetyAction.report => showReportSheet(context, ref, ReportTarget.user(uid)),
        _SafetyAction.block => toggleBlock(context, ref, uid: uid, name: name),
      },
      itemBuilder: (_) => <PopupMenuEntry<_SafetyAction>>[
        const PopupMenuItem<_SafetyAction>(
          value: _SafetyAction.report,
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text(AppStrings.reportAction),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<_SafetyAction>(
          value: _SafetyAction.block,
          child: ListTile(
            leading: Icon(blocked ? Icons.lock_open_outlined : Icons.block),
            title: Text(blocked ? AppStrings.unblockUser : AppStrings.blockUser),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

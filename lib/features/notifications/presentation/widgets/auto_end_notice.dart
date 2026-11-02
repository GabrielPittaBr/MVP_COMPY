import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';

/// Aviso único ao criador de evento encerrado automaticamente (D5, tarefa
/// 14). O mecanismo é a própria notificação, sem campo novo no evento.
///
/// Na primeira emissão das notificações depois que o app abre, procura uma
/// de evento encerrado automaticamente, do próprio criador e ainda não
/// lida. Para a primeira encontrada, marca como lida e mostra o diálogo — é
/// isso que garante o "uma vez só": reabrir o app não acha mais nada.
/// Emissões seguintes, com o app aberto, só mudam o badge do sino.
///
/// Fica em volta do scaffold do shell, que é o primeiro widget montado em
/// toda rota do app, sem mexer na troca de abas.
class AutoEndNotice extends ConsumerStatefulWidget {
  const AutoEndNotice({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoEndNotice> createState() => _AutoEndNoticeState();
}

class _AutoEndNoticeState extends ConsumerState<AutoEndNotice> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<AppNotification>>>(
      notificationsProvider,
      (_, next) => _onNotifications(next),
      fireImmediately: true,
    );
  }

  void _onNotifications(AsyncValue<List<AppNotification>> next) {
    final notifications = next.valueOrNull;
    if (_checked || notifications == null) return;
    _checked = true;

    final uid = ref.read(currentUserSummaryProvider).valueOrNull?.id;
    if (uid == null) return;
    AppNotification? pending;
    for (final n in notifications) {
      if (n.type == AppNotificationType.eventEnded &&
          n.endedAutomatically &&
          n.creatorId == uid &&
          !n.isRead) {
        pending = n;
        break;
      }
    }
    if (pending == null) return;

    // Lida já ao mostrar: se o app fechar com o diálogo aberto, ele não
    // volta. Uma falha aqui só faz o aviso reaparecer na próxima abertura.
    ref.read(markNotificationReadProvider).call(uid, pending.id).ignore();
    final notification = pending;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(notification);
    });
  }

  Future<void> _show(AppNotification notification) async {
    final rate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: AppColors.primary),
        ),
        title: const Text(AppStrings.notificationAutoEndedTitle),
        content: Text(AppStrings.autoEndDialogBody(notification.eventTitle)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.autoEndDialogLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.autoEndDialogRate),
          ),
        ],
      ),
    );
    if (rate == true && mounted) {
      context.push(AppRoutes.eventRatingPath(notification.eventId));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

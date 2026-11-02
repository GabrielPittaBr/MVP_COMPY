import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/models/sport.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/notification_text.dart';
import '../providers/notifications_providers.dart';

/// Central de notificações (tarefa 14, D15), em `/home/notificacoes`.
///
/// "Novas" são as não lidas; "Anteriores", as lidas. Tocar marca como lida e
/// leva à avaliação — ou ao detalhe, se a pessoa já avaliou.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.watch(currentUserSummaryProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notificationsTitle)),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (notifications) {
          if (notifications.isEmpty || uid == null) return const _EmptyState();
          final unread = notifications.where((n) => !n.isRead).toList();
          final read = notifications.where((n) => n.isRead).toList();
          return ListView(
            children: <Widget>[
              if (unread.isNotEmpty) ...<Widget>[
                _SectionHeader(
                  title: AppStrings.notificationsNew,
                  action: TextButton(
                    onPressed: () => ref
                        .read(markAllNotificationsReadProvider)
                        .call(uid, unread.map((n) => n.id)),
                    child: const Text(AppStrings.notificationsMarkAllRead),
                  ),
                ),
                for (final n in unread) _NotificationTile(notification: n, uid: uid),
              ],
              if (read.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: AppStrings.notificationsEarlier),
                for (final n in read) _NotificationTile(notification: n, uid: uid),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.uid});

  final AppNotification notification;
  final String uid;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      // Marcar como lida não segura a navegação; uma falha aqui só deixa o
      // ponto azul para a próxima vez.
      ref
          .read(markNotificationReadProvider)
          .call(uid, notification.id)
          .ignore();
    }
    if (notification.isCompleted) {
      context.go(AppRoutes.eventDetailPath(notification.eventId));
    } else {
      context.push(AppRoutes.eventRatingPath(notification.eventId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).valueOrNull ?? ref.watch(clockProvider)();
    final sport = Sport.tryParse(notification.sport) ?? Sport.futebol;
    final unread = !notification.isRead;

    return InkWell(
      onTap: () => _open(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sport.color.withValues(alpha: 0.16),
              ),
              child: Icon(sport.icon, size: 24, color: sport.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    NotificationText.title(notification, uid),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NotificationText.body(notification, uid),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Text(
                        RelativeTime.of(notification.createdAt, now: now),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                      if (notification.isCompleted) ...<Widget>[
                        const SizedBox(width: 10),
                        const _RatedChip(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Semantics(
                  label: AppStrings.notificationUnread,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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

/// "Avaliado ✓": a pessoa já enviou a avaliação deste evento.
class _RatedChip extends StatelessWidget {
  const _RatedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check, size: 14, color: AppColors.secondary),
          SizedBox(width: 4),
          Text(
            AppStrings.notificationRated,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 44,
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              AppStrings.notificationsEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              AppStrings.notificationsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

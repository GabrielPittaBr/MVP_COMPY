import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/notifications_usecases.dart';

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource?>(
  (ref) => kUseFirebaseRepos
      ? NotificationsRemoteDataSource(FirebaseFirestore.instance)
      : null,
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(
    ref.watch(notificationsRemoteDataSourceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final watchNotificationsProvider = Provider<WatchNotifications>(
  (ref) => WatchNotifications(ref.watch(notificationsRepositoryProvider)),
);

final markNotificationReadProvider = Provider<MarkNotificationRead>(
  (ref) => MarkNotificationRead(ref.watch(notificationsRepositoryProvider)),
);

final markAllNotificationsReadProvider = Provider<MarkAllNotificationsRead>(
  (ref) => MarkAllNotificationsRead(ref.watch(notificationsRepositoryProvider)),
);

/// Notificações do usuário logado, em tempo real (tarefa 14).
final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) async* {
  final watch = ref.watch(watchNotificationsProvider);
  final user = await ref.watch(currentUserSummaryProvider.future);
  yield* watch(user.id);
});

/// Número do badge do sino na Home.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  return notifications?.where((n) => !n.isRead).length ?? 0;
});

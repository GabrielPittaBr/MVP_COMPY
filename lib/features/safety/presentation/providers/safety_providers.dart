import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../data/datasources/in_memory_safety_store.dart';
import '../../data/datasources/safety_remote_datasource.dart';
import '../../data/repositories/safety_repository_impl.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/safety_repository.dart';
import '../../domain/usecases/safety_usecases.dart';

final safetyRemoteProvider = Provider<SafetyRemoteDataSource?>(
  (ref) => kUseFirebaseRepos && firebaseEnabled
      ? SafetyRemoteDataSource(FirebaseFirestore.instance)
      : null,
);

final inMemorySafetyStoreProvider = Provider<InMemorySafetyStore>((ref) {
  final store = InMemorySafetyStore();
  ref.onDispose(store.dispose);
  return store;
});

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepositoryImpl(
    ref.watch(safetyRemoteProvider),
    ref.watch(inMemorySafetyStoreProvider),
  ),
);

final submitReportProvider =
    Provider((ref) => SubmitReport(ref.watch(safetyRepositoryProvider)));
final setBlockedProvider =
    Provider((ref) => SetBlocked(ref.watch(safetyRepositoryProvider)));
final watchBlockedUsersProvider =
    Provider((ref) => WatchBlockedUsers(ref.watch(safetyRepositoryProvider)));

/// Quem o usuário logado bloqueou, numa assinatura só para a sessão.
final blockedUsersProvider = StreamProvider<Set<String>>((ref) {
  final String? uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream<Set<String>>.value(const <String>{});
  return ref.watch(watchBlockedUsersProvider)(uid);
});

/// O usuário logado bloqueou [uid].
final isBlockedProvider = Provider.family<bool, String>(
  (ref, uid) => ref.watch(blockedUsersProvider).valueOrNull?.contains(uid) ?? false,
);

/// Ações de segurança da sessão. Devolvem `true` quando deram certo; a tela
/// decide o que mostrar.
class SafetyActions {
  const SafetyActions(this._ref);
  final Ref _ref;

  Future<bool> report(ReportTarget target, ReportReason reason, String details) async {
    final String? uid = _ref.read(currentUserIdProvider);
    if (uid == null) return false;
    try {
      await _ref.read(submitReportProvider).call(
            reporterId: uid,
            target: target,
            reason: reason,
            details: details,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBlocked(String otherUid, {required bool blocked}) async {
    final String? uid = _ref.read(currentUserIdProvider);
    if (uid == null || uid == otherUid) return false;
    try {
      await _ref.read(setBlockedProvider).call(uid, otherUid, blocked: blocked);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final safetyActionsProvider = Provider<SafetyActions>(SafetyActions.new);

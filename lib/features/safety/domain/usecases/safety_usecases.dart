import '../entities/report.dart';
import '../repositories/safety_repository.dart';

class SubmitReport {
  const SubmitReport(this._repository);
  final SafetyRepository _repository;

  Future<void> call({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    String details = '',
  }) =>
      _repository.report(
        reporterId: reporterId,
        target: target,
        reason: reason,
        details: details.trim(),
      );
}

class WatchBlockedUsers {
  const WatchBlockedUsers(this._repository);
  final SafetyRepository _repository;

  Stream<Set<String>> call(String uid) => _repository.watchBlocked(uid);
}

/// Bloqueia ou desbloqueia: o bloqueio impede, nos dois sentidos, mensagens e
/// pedidos de amizade (ver `canTalk` em `firestore.rules`).
class SetBlocked {
  const SetBlocked(this._repository);
  final SafetyRepository _repository;

  Future<void> call(String uid, String otherUid, {required bool blocked}) =>
      blocked ? _repository.block(uid, otherUid) : _repository.unblock(uid, otherUid);
}

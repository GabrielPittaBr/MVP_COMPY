import '../../domain/entities/report.dart';
import '../../domain/repositories/safety_repository.dart';
import '../datasources/in_memory_safety_store.dart';
import '../datasources/safety_remote_datasource.dart';

/// Firestore quando há Firebase; senão, a memória (modo mock).
class SafetyRepositoryImpl implements SafetyRepository {
  const SafetyRepositoryImpl(this._remote, this._memory);

  final SafetyRemoteDataSource? _remote;
  final InMemorySafetyStore _memory;

  @override
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  }) {
    final SafetyRemoteDataSource? remote = _remote;
    if (remote == null) return _memory.report(reporterId, target, reason, details);
    return remote.report(reporterId: reporterId, target: target, reason: reason, details: details);
  }

  @override
  Stream<Set<String>> watchBlocked(String uid) =>
      _remote?.watchBlocked(uid) ?? _memory.watchBlocked(uid);

  @override
  Future<void> block(String uid, String blockedUid) =>
      _remote?.block(uid, blockedUid) ?? _memory.setBlocked(uid, blockedUid, blocked: true);

  @override
  Future<void> unblock(String uid, String blockedUid) =>
      _remote?.unblock(uid, blockedUid) ?? _memory.setBlocked(uid, blockedUid, blocked: false);
}

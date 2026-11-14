import '../entities/report.dart';

/// Denúncias e bloqueios (chore/lgpd).
abstract interface class SafetyRepository {
  /// Grava a denúncia em `reports`. Ninguém além do Administrador a lê.
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  });

  /// Uids que [uid] bloqueou, ao vivo.
  Stream<Set<String>> watchBlocked(String uid);

  Future<void> block(String uid, String blockedUid);

  Future<void> unblock(String uid, String blockedUid);
}

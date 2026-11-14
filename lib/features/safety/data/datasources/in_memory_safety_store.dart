import 'dart:async';

import '../../domain/entities/report.dart';

/// Denúncias e bloqueios do modo mock (sem Firebase).
class InMemorySafetyStore {
  final Map<String, Set<String>> _blocked = <String, Set<String>>{};
  final List<(String, ReportTarget, ReportReason, String)> reports =
      <(String, ReportTarget, ReportReason, String)>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Future<void> report(String reporterId, ReportTarget target, ReportReason reason, String details) async {
    reports.add((reporterId, target, reason, details));
  }

  Stream<Set<String>> watchBlocked(String uid) async* {
    yield Set<String>.unmodifiable(_blocked[uid] ?? const <String>{});
    await for (final _ in _changes.stream) {
      yield Set<String>.unmodifiable(_blocked[uid] ?? const <String>{});
    }
  }

  Future<void> setBlocked(String uid, String other, {required bool blocked}) async {
    final Set<String> set = _blocked.putIfAbsent(uid, () => <String>{});
    blocked ? set.add(other) : set.remove(other);
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

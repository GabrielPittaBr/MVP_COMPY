import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/report.dart';

/// `reports/{id}` e `users/{uid}/blocks/{blockedUid}` (ver `firestore.rules`).
class SafetyRemoteDataSource {
  const SafetyRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _blocks(String uid) =>
      _firestore.collection('users').doc(uid).collection('blocks');

  /// Os campos são exatamente os que `validReport()` aceita.
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  }) {
    return _firestore.collection('reports').add(<String, Object?>{
      'reporterId': reporterId,
      'targetType': target.type.name,
      'targetId': target.targetId,
      'targetUid': target.targetUid,
      'reason': reason.name,
      'details': details,
      'priority': reason.priority,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      if (target.type == ReportTargetType.message) ...<String, Object?>{
        'conversationId': target.conversationId,
        'messageText': target.messageText,
      },
    });
  }

  Stream<Set<String>> watchBlocked(String uid) => _blocks(uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  Future<void> block(String uid, String blockedUid) => _blocks(uid)
      .doc(blockedUid)
      .set(<String, Object?>{'createdAt': FieldValue.serverTimestamp()});

  Future<void> unblock(String uid, String blockedUid) =>
      _blocks(uid).doc(blockedUid).delete();
}

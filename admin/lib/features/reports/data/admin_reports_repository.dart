import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Motivos que o app grava em `reports/{id}.reason` (chore/lgpd).
const Map<String, String> adminReportReasonLabels = <String, String>{
  'childSafety': 'Envolve criança ou adolescente',
  'harassment': 'Assédio, ameaça ou ofensa',
  'hate': 'Discurso de ódio ou discriminação',
  'sexual': 'Conteúdo sexual',
  'violence': 'Violência',
  'spam': 'Golpe, spam ou venda',
  'fake': 'Perfil ou evento falso',
  'other': 'Outro motivo',
};

enum AdminReportTarget { user, event, message }

/// Denúncia lida de `reports/{id}`. Só o Administrador lê (ver
/// `firestore.rules`); a cópia da mensagem já foi conferida com a original
/// quando a denúncia foi criada.
class AdminReport {
  const AdminReport({
    required this.id,
    required this.reporterId,
    required this.target,
    required this.targetId,
    required this.targetUid,
    required this.reason,
    required this.details,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.conversationId,
    this.messageText,
    this.resolvedAt,
    this.resolution,
  });

  final String id;
  final String reporterId;
  final AdminReportTarget target;
  final String targetId;
  final String targetUid;
  final String reason;
  final String details;

  /// 0 = envolve criança ou adolescente, analisada primeiro.
  final int priority;
  final String status;
  final DateTime? createdAt;
  final String? conversationId;
  final String? messageText;
  final DateTime? resolvedAt;
  final String? resolution;

  bool get isOpen => status == 'open';
  String get reasonLabel => adminReportReasonLabels[reason] ?? reason;

  factory AdminReport.fromDocument(String id, Map<String, dynamic> data) {
    String text(String key) => data[key] is String ? data[key] as String : '';
    DateTime? date(String key) =>
        data[key] is Timestamp ? (data[key] as Timestamp).toDate() : null;
    return AdminReport(
      id: id,
      reporterId: text('reporterId'),
      target: switch (text('targetType')) {
        'event' => AdminReportTarget.event,
        'message' => AdminReportTarget.message,
        _ => AdminReportTarget.user,
      },
      targetId: text('targetId'),
      targetUid: text('targetUid'),
      reason: text('reason'),
      details: text('details'),
      priority: data['priority'] is int ? data['priority'] as int : 1,
      status: text('status'),
      createdAt: date('createdAt'),
      conversationId: data['conversationId'] as String?,
      messageText: data['messageText'] as String?,
      resolvedAt: date('resolvedAt'),
      resolution: data['resolution'] as String?,
    );
  }
}

abstract interface class AdminReportsRepository {
  /// Abertas, as de criança ou adolescente primeiro e, dentro de cada
  /// prioridade, as mais antigas primeiro.
  Future<List<AdminReport>> listOpen();

  /// Fechadas, das mais recentes para as mais antigas.
  Future<List<AdminReport>> listClosed();

  /// Fecha a denúncia. `resolved` = houve ação; `dismissed` = não procede.
  /// O prazo de retenção (12 meses) começa aqui.
  Future<void> close(String reportId, {required bool resolved, required String resolution});
}

class FirestoreAdminReportsRepository implements AdminReportsRepository {
  FirestoreAdminReportsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int _pageSize = 50;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  @override
  Future<List<AdminReport>> listOpen() async {
    final snapshot = await _reports
        .where('status', isEqualTo: 'open')
        .orderBy('priority')
        .orderBy('createdAt')
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => AdminReport.fromDocument(doc.id, doc.data())).toList();
  }

  @override
  Future<List<AdminReport>> listClosed() async {
    final snapshot = await _reports
        .where('status', whereIn: <String>['resolved', 'dismissed'])
        .orderBy('resolvedAt', descending: true)
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => AdminReport.fromDocument(doc.id, doc.data())).toList();
  }

  @override
  Future<void> close(String reportId, {required bool resolved, required String resolution}) {
    final String? adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw StateError('Sessão administrativa ausente.');
    return _reports.doc(reportId).update(<String, Object?>{
      'status': resolved ? 'resolved' : 'dismissed',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminUid,
      'resolution': resolution.trim(),
      // A política de TTL apaga a denúncia 12 meses depois da análise.
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
    });
  }
}

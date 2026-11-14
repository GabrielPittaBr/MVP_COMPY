import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compy_admin/core/routing/admin_router.dart';
import 'package:compy_admin/features/auth/presentation/admin_auth_feature.dart';
import 'package:compy_admin/features/reports/data/admin_reports_repository.dart';
import 'package:compy_admin/features/reports/presentation/admin_reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReportsRepository implements AdminReportsRepository {
  _FakeReportsRepository(this.open);

  final List<AdminReport> open;
  final List<(String, bool, String)> closed = <(String, bool, String)>[];

  @override
  Future<List<AdminReport>> listOpen() async => open;

  @override
  Future<List<AdminReport>> listClosed() async => const <AdminReport>[];

  @override
  Future<void> close(String reportId, {required bool resolved, required String resolution}) async {
    closed.add((reportId, resolved, resolution));
    open.removeWhere((report) => report.id == reportId);
  }
}

AdminReport _report({String id = 'r1', String reason = 'harassment', int priority = 1, String? text}) =>
    AdminReport.fromDocument(id, <String, dynamic>{
      'reporterId': 'ana',
      'targetType': text == null ? 'user' : 'message',
      'targetId': text == null ? 'beto' : 'm1',
      'targetUid': 'beto',
      'reason': reason,
      'details': 'Me ofendeu no chat.',
      'priority': priority,
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 14, 10, 30)),
      if (text != null) 'conversationId': 'c1',
      'messageText': ?text,
    });

void main() {
  test('a fila de denúncias é uma rota conhecida do painel', () {
    expect(adminInitialLocationFromUrl(Uri.parse('https://admin.example/reports')), '/reports');
    expect(
      redirectForAdminRoute(
        location: '/reports',
        accessState: AdminAccessState.signedOut,
        requestedLocation: '/reports',
      ),
      '/login?from=%2Freports',
    );
  });

  test('lê a denúncia de forma tolerante', () {
    final AdminReport report = _report(reason: 'childSafety', priority: 0, text: 'oi');
    expect(report.target, AdminReportTarget.message);
    expect(report.reasonLabel, 'Envolve criança ou adolescente');
    expect(report.messageText, 'oi');
    expect(AdminReport.fromDocument('x', const <String, dynamic>{}).target, AdminReportTarget.user);
  });

  testWidgets('mostra a prioridade, a cópia da mensagem e fecha com nota', (tester) async {
    final _FakeReportsRepository repository = _FakeReportsRepository(<AdminReport>[
      _report(id: 'urgente', reason: 'childSafety', priority: 0, text: 'Mensagem denunciada'),
      _report(),
    ]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportsPage(repository: repository))));
    await tester.pumpAndSettle();

    expect(find.text('Prioridade: criança ou adolescente'), findsOneWidget);
    expect(find.text('“Mensagem denunciada”'), findsOneWidget);
    expect(find.text('Relato: Me ofendeu no chat.'), findsNWidgets(2));

    await tester.tap(find.text('Resolver').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Conta suspensa.');
    await tester.tap(find.widgetWithText(FilledButton, 'Resolver').last);
    await tester.pumpAndSettle();

    expect(repository.closed, <(String, bool, String)>[('urgente', true, 'Conta suspensa.')]);
    expect(find.text('Denúncia resolvida.'), findsOneWidget);
  });
}

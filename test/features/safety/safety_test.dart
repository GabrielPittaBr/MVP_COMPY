import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/safety/data/datasources/in_memory_safety_store.dart';
import 'package:mvp_compy/features/safety/domain/entities/report.dart';
import 'package:mvp_compy/features/safety/presentation/providers/safety_providers.dart';
import 'package:mvp_compy/features/safety/presentation/widgets/report_sheet.dart';
import 'package:mvp_compy/features/safety/presentation/widgets/safety_menu.dart';

void main() {
  late InMemorySafetyStore store;

  setUp(() => store = InMemorySafetyStore());
  tearDown(() => store.dispose());

  Widget app(Widget child) => ProviderScope(
        overrides: <Override>[
          currentUserIdProvider.overrideWithValue('me'),
          safetyRemoteProvider.overrideWithValue(null),
          inMemorySafetyStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  test('a prioridade vai para o topo só quando envolve criança ou adolescente', () {
    expect(ReportReason.childSafety.priority, 0);
    expect(
      ReportReason.values.where((r) => r != ReportReason.childSafety).map((r) => r.priority).toSet(),
      <int>{1},
    );
  });

  testWidgets('denunciar uma mensagem envia motivo, relato e a cópia do texto', (tester) async {
    const ReportTarget target = ReportTarget.message(
      messageId: 'm1',
      conversationId: 'c1',
      senderId: 'other',
      text: 'Mensagem ofensiva',
    );
    await tester.pumpWidget(app(Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => showReportSheet(context, ref, target),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.reportMessageTitle), findsOneWidget);
    // Sem motivo, não envia.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.tap(find.text(AppStrings.reportReasonChildSafety));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.reportEmergencyNote), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Pediu fotos  ');
    await tester.ensureVisible(find.text(AppStrings.reportSubmit));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    await tester.tap(find.text(AppStrings.reportSubmit));
    await tester.pumpAndSettle();

    expect(store.reports, hasLength(1));
    final (String reporter, ReportTarget sent, ReportReason reason, String details) = store.reports.single;
    expect(reporter, 'me');
    expect(sent, target);
    expect(reason, ReportReason.childSafety);
    expect(details, 'Pediu fotos');
    expect(find.text(AppStrings.reportSent), findsOneWidget);
  });

  testWidgets('bloquear pede confirmação; desbloquear, não', (tester) async {
    await tester.pumpWidget(app(const UserSafetyMenu(uid: 'other', name: 'Ana')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.blockUser));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.blockConfirmTitle('Ana')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, AppStrings.blockUser));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.blockDone), findsOneWidget);
    expect(await store.watchBlocked('me').first, <String>{'other'});
    // O SnackBar seguinte entra na fila atrás deste.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.unblockUser));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.unblockDone), findsOneWidget);
    expect(await store.watchBlocked('me').first, isEmpty);
  });
}

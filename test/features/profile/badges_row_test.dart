import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/profile/domain/entities/badge.dart';
import 'package:mvp_compy/features/profile/presentation/widgets/badges_row.dart';

void main() {
  Future<int> pumpRow(
    WidgetTester tester, {
    List<SportBadge> badges = const <SportBadge>[],
  }) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BadgesRow(badges: badges, onSeeMore: () => taps++),
        ),
      ),
    );
    return taps;
  }

  group('BadgesRow', () {
    // O caminho Firestore devolve `badges: const []`, então a fileira vazia é
    // o caso real de todo usuário hoje — e o "Ver mais" é o único item dela.
    testWidgets('"Ver mais" é clicável mesmo sem nenhuma insígnia',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BadgesRow(badges: const [], onSeeMore: () => taps++),
          ),
        ),
      );

      expect(find.text(AppStrings.profileSeeMore), findsOneWidget);

      await tester.tap(find.text(AppStrings.profileSeeMore));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('mostra as insígnias recebidas junto do "Ver mais"',
        (tester) async {
      await pumpRow(
        tester,
        badges: const <SportBadge>[
          SportBadge(
            id: 'b1',
            label: 'Maratonista',
            icon: Icons.directions_run,
            color: Colors.orange,
          ),
        ],
      );

      expect(find.text('Maratonista'), findsOneWidget);
      expect(find.text(AppStrings.profileSeeMore), findsOneWidget);
    });
  });
}

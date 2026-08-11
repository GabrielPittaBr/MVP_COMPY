import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/profile/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/profile/presentation/widgets/rating_breakdown.dart';

void main() {
  Future<void> pumpBreakdown(WidgetTester tester, RatingSummary summary) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RatingBreakdown(summary: summary)),
      ),
    );
  }

  group('RatingBreakdown — sem avaliação nenhuma', () {
    const RatingSummary vazio =
        RatingSummary(average: 0, count: 0, breakdown: <int, double>{});

    // É o caso de todo usuário real hoje: o caminho Firestore do repositório
    // devolve RatingSummary(average: 0, count: 0) fixo.
    testWidgets('diz que não há avaliações em vez de mostrar 0,0',
        (tester) async {
      await pumpBreakdown(tester, vazio);

      expect(find.text(AppStrings.profileNoRatings), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatingsHint), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('não desenha estrelas nem barras de distribuição',
        (tester) async {
      await pumpBreakdown(tester, vazio);

      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('RatingBreakdown — com avaliações', () {
    testWidgets('volta a mostrar média, estrelas e distribuição',
        (tester) async {
      await pumpBreakdown(
        tester,
        const RatingSummary(
          average: 4.8,
          count: 12,
          breakdown: <int, double>{5: 0.8, 4: 0.2},
        ),
      );

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('12 avaliações'), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatings), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    });

    // Uma única avaliação já é avaliação: o corte é count > 0, não a média.
    testWidgets('média 0 com uma avaliação ainda é uma nota', (tester) async {
      await pumpBreakdown(
        tester,
        const RatingSummary(
          average: 0,
          count: 1,
          breakdown: <int, double>{1: 1},
        ),
      );

      expect(find.text('0.0'), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatings), findsNothing);
    });
  });
}

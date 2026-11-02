import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/profile/presentation/widgets/rating_breakdown.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_summary.dart';
import 'package:mvp_compy/shared/widgets/star_rating.dart';

void main() {
  Future<void> pumpBreakdown(
    WidgetTester tester,
    RatingSummary summary, {
    bool isOwnProfile = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingBreakdown(summary: summary, isOwnProfile: isOwnProfile),
        ),
      ),
    );
  }

  group('RatingBreakdown — sem avaliação nenhuma', () {
    testWidgets('no próprio perfil, fala em primeira pessoa em vez de 0,0',
        (tester) async {
      await pumpBreakdown(tester, RatingSummary.empty);

      expect(find.text(AppStrings.profileNoRatings), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatingsHint), findsOneWidget);
      expect(find.text('0,0'), findsNothing);
    });

    testWidgets('no perfil de outra pessoa, o neutro "Sem avaliações ainda"',
        (tester) async {
      await pumpBreakdown(tester, RatingSummary.empty, isOwnProfile: false);

      expect(find.text(AppStrings.ratingsNone), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatings), findsNothing);
    });

    testWidgets('não desenha estrelas nem barras de distribuição',
        (tester) async {
      await pumpBreakdown(tester, RatingSummary.empty);

      expect(find.byType(StarRating), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('RatingBreakdown — com avaliações', () {
    testWidgets('média com vírgula, estrelas, plural e distribuição',
        (tester) async {
      await pumpBreakdown(
        tester,
        RatingSummary.fromAggregate(
          count: 12,
          sum: 58,
          starCounts: const <int, int>{5: 10, 4: 2},
        ),
      );

      expect(find.text('4,8'), findsOneWidget);
      expect(find.text('4.8'), findsNothing);
      expect(find.text('12 avaliações'), findsOneWidget);
      expect(find.byType(StarRating), findsOneWidget);
      expect(find.text('83%'), findsOneWidget);
      expect(find.text('17%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    });

    testWidgets('uma avaliação só usa o singular', (tester) async {
      await pumpBreakdown(
        tester,
        RatingSummary.fromAggregate(
          count: 1,
          sum: 1,
          starCounts: const <int, int>{1: 1},
        ),
      );

      expect(find.text('1,0'), findsOneWidget);
      expect(find.text('1 avaliação'), findsOneWidget);
      expect(find.text(AppStrings.profileNoRatings), findsNothing);
    });
  });
}

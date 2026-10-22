import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/maps/presentation/widgets/place_rating_row.dart';
import 'package:mvp_compy/features/ratings/data/datasources/in_memory_ratings_store.dart';
import 'package:mvp_compy/features/ratings/data/datasources/ratings_remote_datasource.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/ratings/presentation/providers/ratings_providers.dart';

void main() {
  group('RatingSummary.fromAggregate', () {
    test('média = soma / contagem, distribuição por estrela', () {
      final resumo = RatingSummary.fromAggregate(
        count: 8,
        sum: 37,
        starCounts: const <int, int>{5: 5, 4: 2, 3: 1},
      );

      expect(resumo.average, 37 / 8);
      expect(resumo.count, 8);
      expect(resumo.breakdown, <int, double>{
        1: 0,
        2: 0,
        3: 1 / 8,
        4: 2 / 8,
        5: 5 / 8,
      });
      expect(resumo.hasRatings, isTrue);
    });

    test('contagem zero é o resumo vazio', () {
      expect(
        RatingSummary.fromAggregate(count: 0, sum: 0, starCounts: const {}),
        RatingSummary.empty,
      );
      expect(RatingSummary.empty.hasRatings, isFalse);
    });

    test('lê o documento de ratingSummaries, com as chaves em texto', () {
      final resumo = RatingsRemoteDataSource.fromAggregate(<String, dynamic>{
        'targetType': 'place',
        'targetId': 'p1',
        'count': 23,
        'sum': 99,
        'starCounts': <String, dynamic>{'5': 10, '4': 8, '3': 3, '2': 2},
      });

      expect(resumo.count, 23);
      expect(resumo.average, 99 / 23);
      expect(resumo.breakdown[5], 10 / 23);
      expect(RatingsRemoteDataSource.fromAggregate(null), RatingSummary.empty);
    });
  });

  test('o mock traz o 4,8 com 12 avaliações do perfil do João', () {
    final resumo = InMemoryRatingsStore.instance
        .summaryOf((type: RatingTargetType.user, id: 'u_joao'));

    expect(resumo.count, 12);
    expect(resumo.average, closeTo(4.83, 0.01));
  });

  group('PlaceRatingRow', () {
    Future<void> pump(WidgetTester tester, RatingSummary resumo) {
      return tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          ratingSummaryProvider.overrideWith(
              (ref, target) => Stream<RatingSummary>.value(resumo)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PlaceRatingRow(placeId: 'p1')),
        ),
      ));
    }

    testWidgets('com avaliações: estrelas, média com vírgula e contagem',
        (tester) async {
      await pump(
        tester,
        RatingSummary.fromAggregate(
          count: 23,
          sum: 99,
          starCounts: const <int, int>{5: 10, 4: 8, 3: 3, 2: 2},
        ),
      );
      await tester.pump();

      expect(find.text('4,3'), findsOneWidget);
      expect(find.text('(23 avaliações)'), findsOneWidget);
    });

    testWidgets('sem avaliações: "Sem avaliações ainda"', (tester) async {
      await pump(tester, RatingSummary.empty);
      await tester.pump();

      expect(find.text(AppStrings.ratingsNone), findsOneWidget);
    });
  });
}

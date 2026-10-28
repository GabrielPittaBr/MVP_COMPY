import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_status.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/event_card.dart';
import 'package:mvp_compy/shared/widgets/event_skill_level_chip.dart';

Event _event(SkillLevel level) => Event(
      id: 'evt_card',
      title: 'Treino de tênis de mesa no bairro',
      sport: Sport.tenisDeMesa,
      location: 'Ginásio Municipal de Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: DateTime(2026, 10, 26, 18),
      skillLevel: level,
      totalSpots: 10,
      remainingSpots: 4,
      bannerUrl: '',
      creator: const UserSummary(
          id: 'uid', name: 'Ana', handle: '@ana', avatarUrl: ''),
    );

void main() {
  for (final level in SkillLevel.values) {
    testWidgets('card mostra ${level.label}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EventCard(
            event: _event(level),
            actionLabel: AppStrings.eventSeeMore,
            onAction: () {},
          ),
        ),
      ));

      final expected = level == SkillLevel.todos
          ? AppStrings.eventAllSkillLevels
          : level.label;
      expect(find.text(expected), findsOneWidget);
      expect(
          tester
              .widget<EventSkillLevelChip>(find.byType(EventSkillLevelChip))
              .level,
          level);
    });
  }

  testWidgets('card estreito não apresenta overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EventCard(
            event: _event(SkillLevel.todos),
            status: EventStatus.happening,
            actionLabel: AppStrings.eventSeeMore,
            onAction: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text(AppStrings.eventAllSkillLevels), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

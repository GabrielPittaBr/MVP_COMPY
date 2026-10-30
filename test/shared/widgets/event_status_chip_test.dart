import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_status.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/event_card.dart';
import 'package:mvp_compy/shared/widgets/event_status_chip.dart';

final _agora = DateTime(2026, 10, 21, 19, 20);

final _aoVivo = Event(
  id: 'evt_card',
  title: 'Rachão',
  sport: Sport.basquete,
  location: 'Taquara',
  coordinates: const LatLng(-29.65, -50.78),
  dateTime: DateTime(2026, 10, 21, 19),
  skillLevel: SkillLevel.todos,
  totalSpots: 10,
  remainingSpots: 4,
  bannerUrl: '',
  creator: const UserSummary(id: 'u', name: 'U', handle: '@u', avatarUrl: ''),
);

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  ));
}

void main() {
  testWidgets('acontecendo: texto escuro e ponto verde', (tester) async {
    await _pump(tester, const EventStatusChip(status: EventStatus.happening));

    final texto = tester.widget<Text>(find.text(AppStrings.eventStatusLive));
    expect(texto.style!.color, const Color(0xFF0A0A0A));
  });

  testWidgets('encerrado aparece em cinza, com o texto do automático',
      (tester) async {
    await _pump(
      tester,
      const Column(children: <Widget>[
        EventStatusChip(status: EventStatus.ended),
        EventStatusChip(status: EventStatus.ended, endedAutomatically: true),
      ]),
    );

    final texto = tester.widget<Text>(find.text(AppStrings.eventStatusEnded));
    expect(texto.style!.color, const Color(0xFF6B7280));
    expect(find.text(AppStrings.eventStatusEndedAutomatically), findsOneWidget);
  });

  testWidgets('agendado não tem selo', (tester) async {
    await _pump(tester, const EventStatusChip(status: EventStatus.scheduled));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('o card mostra o selo no lugar do calendário quando acontece',
      (tester) async {
    await _pump(
      tester,
      EventStatusBuilder(
        event: _aoVivo,
        builder: (context, status) => EventCard(
          event: _aoVivo,
          status: status,
          actionLabel: AppStrings.eventSeeMore,
          onOpen: () {},
        ),
      ),
    );

    expect(find.text(AppStrings.eventStatusLive), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets('sem status, o card mantém o calendário', (tester) async {
    await _pump(
      tester,
      EventCard(
        event: _aoVivo,
        actionLabel: AppStrings.eventSeeMore,
        onOpen: () {},
      ),
    );

    expect(find.text(AppStrings.eventStatusLive), findsNothing);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });
}

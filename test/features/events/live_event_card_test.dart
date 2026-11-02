import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/events_list_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

final _agora = DateTime(2026, 10, 21, 19, 30);

const _dono = UserSummary(
  id: 'u_dono',
  name: 'Ana Souza',
  handle: '@anasouza',
  avatarUrl: '',
);
const _participante = UserSummary(
  id: 'u_participante',
  name: 'Bruno Lima',
  handle: '@brunolima',
  avatarUrl: '',
);
const _visitante = UserSummary(
  id: 'u_visitante',
  name: 'Carla Mendes',
  handle: '@carlamendes',
  avatarUrl: '',
);

Event _aoVivo({Duration comecouHa = const Duration(minutes: 20)}) => Event(
      id: 'evt_ao_vivo',
      title: 'Rachão',
      sport: Sport.basquete,
      location: 'Parque do Trabalhador, Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: _agora.subtract(comecouHa),
      durationMinutes: 60,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: 8,
      bannerUrl: '',
      creator: _dono,
      participants: const <UserSummary>[_dono, _participante],
    );

/// Repositório que responde como o Firestore: a consulta de "Participando"
/// é por `participantIds`, então só quem participa recebe o evento.
class _Repositorio implements EventsRepository {
  _Repositorio(this.evento);

  final Event evento;

  @override
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize = 10,
    EventsFilter filter = const EventsFilter(),
  }) async =>
      PagedResult<Event>(items: <Event>[evento], hasMore: false);

  @override
  Future<List<Event>> fetchCreatedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async =>
      const <Event>[];

  @override
  Stream<List<Event>> watchJoinedActive(String uid) =>
      Stream<List<Event>>.value(<Event>[
        if (evento.participantIds.contains(uid)) evento,
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrirAba(
  WidgetTester tester, {
  required UserSummary quem,
  Event? evento,
  EventsFilter filtro = const EventsFilter(),
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(
        _Repositorio(evento ?? _aoVivo()),
      ),
      eventsFilterProvider.overrideWith((ref) => filtro),
    ],
    child: const MaterialApp(home: EventsListPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o participante vê o card ao vivo no topo', (tester) async {
    await _abrirAba(tester, quem: _participante);

    expect(find.text(AppStrings.eventLiveBadge), findsOneWidget);
    expect(find.text(AppStrings.eventLiveOpen), findsOneWidget);
    expect(find.text(AppStrings.eventLiveRemaining('40min')), findsOneWidget);
  });

  testWidgets('o criador também vê o card', (tester) async {
    await _abrirAba(tester, quem: _dono);

    expect(find.text(AppStrings.eventLiveBadge), findsOneWidget);
  });

  testWidgets('quem não participa não vê o card, só o selo na lista',
      (tester) async {
    await _abrirAba(tester, quem: _visitante);

    expect(find.text(AppStrings.eventLiveBadge), findsNothing);
    expect(find.text(AppStrings.eventStatusLive), findsOneWidget);
  });

  testWidgets('o card não depende do filtro da aba', (tester) async {
    await _abrirAba(
      tester,
      quem: _participante,
      filtro: const EventsFilter(sport: Sport.futebol),
    );

    expect(find.text(AppStrings.eventLiveBadge), findsOneWidget);
    // "Participando" aplica o filtro: o basquete não aparece na seção.
    expect(find.text(AppStrings.eventsSectionJoined), findsNothing);
  });

  testWidgets('em atraso, o card avisa "Horário previsto encerrado"',
      (tester) async {
    await _abrirAba(
      tester,
      quem: _participante,
      evento: _aoVivo(comecouHa: const Duration(minutes: 75)),
    );

    expect(find.text(AppStrings.eventLiveOverdue), findsOneWidget);
  });
}

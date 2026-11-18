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

final _agora = DateTime(2026, 11, 17, 10);

const _eu = UserSummary(id: 'u_eu', name: 'Eu', handle: '@eu', avatarUrl: '');
const _outra = UserSummary(
  id: 'u_outra',
  name: 'Outra',
  handle: '@outra',
  avatarUrl: '',
);

Event _evento(
  String titulo, {
  required UserSummary criador,
  List<UserSummary> outros = const <UserSummary>[],
}) =>
    Event(
      id: titulo,
      title: titulo,
      sport: Sport.futebol,
      location: 'Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      // Amanhã: agendado, para o card ao vivo não repetir o título.
      dateTime: _agora.add(const Duration(days: 1)),
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: 5,
      bannerUrl: '',
      creator: criador,
      // O Organizador sempre entra como Participante.
      participants: <UserSummary>[criador, ...outros],
    );

final _criei = _evento('Criei', criador: _eu);
final _entrei =
    _evento('Entrei', criador: _outra, outros: const <UserSummary>[_eu]);
final _deOutra = _evento('De outra pessoa', criador: _outra);

/// Responde como o Firestore: a lista paginada traz tudo, e as seções
/// pessoais vêm das consultas por `creator.id` e por `participantIds`.
class _Repositorio implements EventsRepository {
  final List<Event> todos = <Event>[_criei, _entrei, _deOutra];

  @override
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize = 10,
    EventsFilter filter = const EventsFilter(),
  }) async =>
      PagedResult<Event>(items: todos, hasMore: false);

  @override
  Future<List<Event>> fetchCreatedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async =>
      <Event>[
        for (final e in todos)
          if (e.creator.id == uid) e,
      ];

  @override
  Stream<List<Event>> watchJoinedActive(String uid) =>
      Stream<List<Event>>.value(<Event>[
        for (final e in todos)
          if (e.participantIds.contains(uid)) e,
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrirAba(WidgetTester tester, UserSummary quem) async {
  // Alta o bastante para as três seções caberem sem rolar.
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(_Repositorio()),
    ],
    child: const MaterialApp(home: EventsListPage()),
  ));
  await tester.pumpAndSettle();
}

/// Posição vertical do texto, para conferir em que seção o card caiu.
double _y(WidgetTester tester, String texto) =>
    tester.getTopLeft(find.text(texto)).dy;

void main() {
  testWidgets('cada evento aparece numa seção só', (tester) async {
    await _abrirAba(tester, _eu);

    for (final titulo in <String>['Criei', 'Entrei', 'De outra pessoa']) {
      expect(find.text(titulo), findsOneWidget, reason: titulo);
    }

    final mine = _y(tester, AppStrings.eventsSectionMine);
    final joined = _y(tester, AppStrings.eventsSectionJoined);
    final others = _y(tester, AppStrings.eventsSectionAll);
    expect(mine, lessThan(_y(tester, 'Criei')));
    expect(_y(tester, 'Criei'), lessThan(joined));
    expect(joined, lessThan(_y(tester, 'Entrei')));
    expect(_y(tester, 'Entrei'), lessThan(others));
    expect(others, lessThan(_y(tester, 'De outra pessoa')));
  });

  testWidgets('quem não criou nem entrou vê a lista simples, sem títulos',
      (tester) async {
    await _abrirAba(
      tester,
      const UserSummary(
        id: 'u_visitante',
        name: 'Visitante',
        handle: '@visitante',
        avatarUrl: '',
      ),
    );

    expect(find.text('Criei'), findsOneWidget);
    expect(find.text('Entrei'), findsOneWidget);
    expect(find.text(AppStrings.eventsSectionMine), findsNothing);
    expect(find.text(AppStrings.eventsSectionJoined), findsNothing);
    expect(find.text(AppStrings.eventsSectionAll), findsNothing);
  });
}

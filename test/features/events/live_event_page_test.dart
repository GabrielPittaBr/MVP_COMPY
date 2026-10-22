import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/live_event_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
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
const _outro = UserSummary(
  id: 'u_outro',
  name: 'Diego Rocha',
  handle: '@diegorocha',
  avatarUrl: '',
);
const _visitante = UserSummary(
  id: 'u_visitante',
  name: 'Carla Mendes',
  handle: '@carlamendes',
  avatarUrl: '',
);

final _evento = Event(
  id: 'evt_ao_vivo',
  title: 'Rachão',
  sport: Sport.basquete,
  location: 'Parque do Trabalhador, Taquara',
  coordinates: const LatLng(-29.65, -50.78),
  dateTime: _agora.subtract(const Duration(minutes: 20)),
  durationMinutes: 60,
  skillLevel: SkillLevel.todos,
  totalSpots: 10,
  remainingSpots: 7,
  bannerUrl: '',
  creator: _dono,
  participants: const <UserSummary>[_dono, _participante, _outro],
);

class _Repositorio implements EventsRepository {
  @override
  Stream<Event?> watchById(String id) => Stream<Event?>.value(_evento);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrir(WidgetTester tester, UserSummary quem) async {
  // Tela alta o bastante para a lista inteira: o ListView só constrói o que
  // aparece.
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/events/evt_ao_vivo/ao-vivo',
    routes: <RouteBase>[
      GoRoute(
        path: '/events/:id',
        builder: (_, __) => const Scaffold(body: Text('detalhe do evento')),
        routes: <RouteBase>[
          GoRoute(
            path: 'ao-vivo',
            builder: (_, state) =>
                LiveEventPage(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(_Repositorio()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Finder _mensagemPara(UserSummary pessoa) =>
    find.byTooltip(AppStrings.eventLiveMessage(pessoa.name));

void main() {
  testWidgets(
      'o participante vê todos, com mensagem para os outros e não '
      'para si', (tester) async {
    await _abrir(tester, _participante);

    expect(find.text(AppStrings.eventLiveTitle), findsOneWidget);
    expect(find.text(AppStrings.eventLiveTalkToOrganizer), findsOneWidget);
    expect(find.text(AppStrings.eventLiveOrganizer), findsOneWidget);
    expect(find.text(AppStrings.eventLiveYou), findsOneWidget);
    expect(_mensagemPara(_dono), findsOneWidget);
    expect(_mensagemPara(_outro), findsOneWidget);
    expect(_mensagemPara(_participante), findsNothing);
  });

  testWidgets(
      'o criador não tem "Falar com o organizador" nem mensagem '
      'para si', (tester) async {
    await _abrir(tester, _dono);

    expect(find.text(AppStrings.eventLiveTalkToOrganizer), findsNothing);
    expect(_mensagemPara(_dono), findsNothing);
    expect(_mensagemPara(_participante), findsOneWidget);
  });

  testWidgets('quem não participa vai para o detalhe', (tester) async {
    await _abrir(tester, _visitante);

    expect(find.text('detalhe do evento'), findsOneWidget);
    expect(find.text(AppStrings.eventLiveTitle), findsNothing);
  });
}

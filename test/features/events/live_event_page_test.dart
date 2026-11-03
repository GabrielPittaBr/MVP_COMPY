import 'dart:async';

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
import 'package:mvp_compy/shared/widgets/event_skill_level_chip.dart';
import 'package:mvp_compy/shared/widgets/event_info_row.dart';

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
  _Repositorio({Stream<Event?>? evento, this.erroAoEncerrar})
      : evento = evento ?? Stream<Event?>.value(_evento);

  final Stream<Event?> evento;
  final Object? erroAoEncerrar;
  final List<String> encerrados = <String>[];

  @override
  Stream<Event?> watchById(String id) => evento;

  @override
  Future<void> endEvent(String eventId) async {
    if (erroAoEncerrar != null) throw erroAoEncerrar!;
    encerrados.add(eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrir(
  WidgetTester tester,
  UserSummary quem, {
  _Repositorio? repositorio,
  Size size = const Size(420, 1400),
  double textScale = 1,
}) async {
  // Tela alta o bastante para a lista inteira: o ListView só constrói o que
  // aparece.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/events/evt_ao_vivo/ao-vivo',
    routes: <RouteBase>[
      GoRoute(
        path: '/avaliacao/:eventId',
        builder: (_, __) => const Scaffold(body: Text('avaliação do evento')),
      ),
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
      eventsRepositoryProvider.overrideWithValue(repositorio ?? _Repositorio()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _mensagemPara(UserSummary pessoa) =>
    find.byTooltip(AppStrings.eventLiveMessage(pessoa.name));

void main() {
  for (final level in SkillLevel.values) {
    testWidgets('evento em andamento mostra ${level.label} sem chip',
        (tester) async {
      final event = Event.fromMap(
          'evt_ao_vivo', _evento.toMap()..['skillLevel'] = level.name);
      await _abrir(tester, _participante,
          repositorio: _Repositorio(evento: Stream.value(event)));
      final label = level == SkillLevel.todos
          ? AppStrings.eventAllSkillLevels
          : level.label;
      expect(find.text(label), findsOneWidget);
      expect(find.byType(EventSkillLevelChip), findsNothing);
      final skill =
          find.widgetWithIcon(EventInfoRow, Icons.trending_up_outlined);
      final sport = find.widgetWithIcon(EventInfoRow, event.sport.icon);
      expect(tester.getTopLeft(find.text(label)).dx,
          tester.getTopLeft(find.text(event.sport.label)).dx);
      expect(tester.widget<Text>(find.text(label)).style,
          tester.widget<Text>(find.text(event.sport.label)).style);
      expect(tester.getTopLeft(skill).dy - tester.getBottomLeft(sport).dy, 8);
      expect(find.descendant(of: skill, matching: find.byType(DecoratedBox)),
          findsNothing);
      expect(find.text(AppStrings.eventLiveSchedule('19:10', '20:10')),
          findsOneWidget);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          closeTo(1 / 3, 0.001));
    });
  }

  testWidgets(
      'evento em andamento comporta título longo e texto ampliado em tela estreita',
      (tester) async {
    final event = Event.fromMap(
        'evt_ao_vivo',
        _evento.toMap()
          ..['title'] =
              'Treino de tênis de mesa para todos os moradores do bairro'
          ..['sport'] = Sport.tenisDeMesa.name);
    await _abrir(tester, _participante,
        repositorio: _Repositorio(evento: Stream.value(event)),
        size: const Size(360, 1400),
        textScale: 1.2);
    expect(find.text(AppStrings.eventAllSkillLevels), findsOneWidget);
    expect(find.text(Sport.tenisDeMesa.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'o participante vê todos, com mensagem para os outros e não '
      'para si', (tester) async {
    await _abrir(tester, _participante);

    expect(find.text(AppStrings.eventLiveTitle), findsOneWidget);
    expect(find.text(AppStrings.eventLiveTalkToOrganizer), findsOneWidget);
    await tester.tap(find.byKey(const Key('participants-see-all')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.eventLiveOrganizer), findsNWidgets(2));
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
    await tester.tap(find.byKey(const Key('participants-see-all')));
    await tester.pumpAndSettle();
    expect(_mensagemPara(_dono), findsNothing);
    expect(_mensagemPara(_participante), findsOneWidget);
  });

  testWidgets('quem não participa vai para o detalhe', (tester) async {
    await _abrir(tester, _visitante);

    expect(find.text('detalhe do evento'), findsOneWidget);
    expect(find.text(AppStrings.eventLiveTitle), findsNothing);
  });

  group('encerrar (ticket 08)', () {
    testWidgets('o criador vê "Encerrar evento"', (tester) async {
      await _abrir(tester, _dono);
      expect(find.text(AppStrings.eventEnd), findsOneWidget);
    });

    testWidgets('o participante não vê "Encerrar evento"', (tester) async {
      await _abrir(tester, _participante);
      expect(find.text(AppStrings.eventEnd), findsNothing);
    });

    testWidgets('pede confirmação, e cancelar não encerra', (tester) async {
      final repositorio = _Repositorio();
      await _abrir(tester, _dono, repositorio: repositorio);

      await tester.tap(find.text(AppStrings.eventEnd));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.eventEndConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.eventEndConfirmBody), findsOneWidget);

      await tester.tap(find.text(AppStrings.commonCancel));
      await tester.pumpAndSettle();
      expect(repositorio.encerrados, isEmpty);
      expect(find.text(AppStrings.eventLiveTitle), findsOneWidget);
    });

    testWidgets('confirmar encerra e leva o criador à avaliação',
        (tester) async {
      final repositorio = _Repositorio();
      await _abrir(tester, _dono, repositorio: repositorio);

      await tester.tap(find.text(AppStrings.eventEnd));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.eventEndConfirm));
      await tester.pumpAndSettle();

      expect(repositorio.encerrados, <String>['evt_ao_vivo']);
      expect(find.text('avaliação do evento'), findsOneWidget);
    });

    testWidgets('evento que já tinha sido encerrado mostra a mensagem certa',
        (tester) async {
      await _abrir(
        tester,
        _dono,
        repositorio: _Repositorio(
          erroAoEncerrar: const EventAlreadyEndedException(),
        ),
      );

      await tester.tap(find.text(AppStrings.eventEnd));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.eventEndConfirm));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.eventAlreadyEndedError), findsOneWidget);
    });

    testWidgets('o participante vê a faixa quando o organizador encerra',
        (tester) async {
      final documento = StreamController<Event?>();
      addTearDown(documento.close);
      documento.add(_evento);
      await _abrir(
        tester,
        _participante,
        repositorio: _Repositorio(evento: documento.stream),
      );
      expect(find.text(AppStrings.eventEndedByOrganizer), findsNothing);

      documento.add(_evento.copyWith(endedAt: _agora));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.eventEndedByOrganizer), findsOneWidget);
      expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);

      // A faixa leva à avaliação ("Avaliar agora").
      await tester.tap(find.text(AppStrings.eventLiveRateNow));
      await tester.pumpAndSettle();
      expect(find.text('avaliação do evento'), findsOneWidget);
    });

    // Começou há 20 min e durava 15: passou 5 min do previsto.
    final atrasado = _evento.copyWith(durationMinutes: 15);

    testWidgets('em atraso, o criador é chamado a encerrar', (tester) async {
      await _abrir(
        tester,
        _dono,
        repositorio: _Repositorio(evento: Stream<Event?>.value(atrasado)),
      );
      expect(find.text(AppStrings.eventLiveOverdueCreator), findsOneWidget);
    });

    testWidgets('em atraso, o participante sabe que falta o organizador',
        (tester) async {
      await _abrir(
        tester,
        _participante,
        repositorio: _Repositorio(evento: Stream<Event?>.value(atrasado)),
      );
      expect(find.text(AppStrings.eventLiveOverdueParticipant), findsOneWidget);
      expect(
        find.text(AppStrings.eventLiveOverdueBy('5min')),
        findsOneWidget,
      );
    });
  });
}

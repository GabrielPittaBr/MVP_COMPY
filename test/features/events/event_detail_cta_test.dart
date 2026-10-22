import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/event_detail_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

/// Relógio fixo: o evento de teste começa uma hora depois dele.
final _agora = DateTime(2026, 10, 21, 18);

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

Event _evento({
  Duration inicioEm = const Duration(hours: 1),
  DateTime? endedAt,
  bool endedAutomatically = false,
  int remainingSpots = 8,
}) =>
    Event(
      id: 'evt_detalhe',
      title: 'Rachão',
      sport: Sport.basquete,
      location: 'Parque do Trabalhador, Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: _agora.add(inicioEm),
      durationMinutes: 60,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: remainingSpots,
      bannerUrl: '',
      creator: _dono,
      participants: const <UserSummary>[_dono, _participante],
      endedAt: endedAt,
      endedAutomatically: endedAutomatically,
    );

class _EventoAoVivo implements EventsRepository {
  _EventoAoVivo(this.eventos);

  final Stream<Event?> eventos;

  @override
  Stream<Event?> watchById(String id) => eventos;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrir(
  WidgetTester tester, {
  required Stream<Event?> evento,
  required UserSummary quem,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(_EventoAoVivo(evento)),
    ],
    child: const MaterialApp(home: EventDetailPage(eventId: 'evt_detalhe')),
  ));
  await tester.pumpAndSettle();
}

Finder _botao(String label) => find.widgetWithText(FilledButton, label);

void main() {
  // O detalhe escreve o dia da semana em pt_BR, como o main.dart prepara.
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('agendado', () {
    testWidgets('quem não participa vê "Participar"', (tester) async {
      await _abrir(tester, evento: Stream.value(_evento()), quem: _visitante);

      expect(_botao(AppStrings.eventJoin), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_botao(AppStrings.eventJoin)).onPressed,
        isNotNull,
      );
      expect(find.text(AppStrings.eventStatusLive), findsNothing);
    });

    testWidgets('lotado, quem não participa vê "Evento sem vagas"',
        (tester) async {
      await _abrir(
        tester,
        evento: Stream.value(_evento(remainingSpots: 0)),
        quem: _visitante,
      );

      expect(
        tester.widget<FilledButton>(_botao(AppStrings.eventFull)).onPressed,
        isNull,
      );
    });

    testWidgets('o participante vê "Você está participando"', (tester) async {
      await _abrir(tester,
          evento: Stream.value(_evento()), quem: _participante);

      expect(find.text(AppStrings.eventYouAreIn), findsOneWidget);
      expect(_botao(AppStrings.eventJoin), findsNothing);
    });

    testWidgets('o criador vê "Você organiza este evento"', (tester) async {
      await _abrir(tester, evento: Stream.value(_evento()), quem: _dono);

      expect(find.text(AppStrings.eventYouOrganize), findsOneWidget);
      expect(_botao(AppStrings.eventJoin), findsNothing);
    });
  });

  group('acontecendo, participante ou criador', () {
    for (final quem in <UserSummary>[_participante, _dono]) {
      testWidgets('${quem.id} vê "Abrir evento ao vivo"', (tester) async {
        await _abrir(
          tester,
          evento: Stream.value(_evento(inicioEm: const Duration(minutes: -20))),
          quem: quem,
        );

        expect(find.text(AppStrings.eventStatusLive), findsOneWidget);
        expect(_botao(AppStrings.eventLiveOpenFromDetail), findsOneWidget);
        expect(_botao(AppStrings.eventJoin), findsNothing);
      });
    }
  });

  testWidgets('acontecendo, quem não participa ainda vê "Participar"',
      (tester) async {
    await _abrir(
      tester,
      evento: Stream.value(_evento(inicioEm: const Duration(minutes: -20))),
      quem: _visitante,
    );

    expect(find.text(AppStrings.eventStatusLive), findsOneWidget);
    expect(_botao(AppStrings.eventJoin), findsOneWidget);
  });

  group('encerrado', () {
    testWidgets('para todos: selo "Encerrado" e nenhuma ação', (tester) async {
      final encerrado = _evento(
        inicioEm: const Duration(hours: -2),
        endedAt: _agora.subtract(const Duration(minutes: 50)),
      );
      for (final quem in <UserSummary>[_visitante, _participante, _dono]) {
        await _abrir(tester, evento: Stream.value(encerrado), quem: quem);

        expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);
        expect(find.text(AppStrings.eventAlreadyEnded), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing, reason: quem.id);
      }
    });

    testWidgets('encerrado pela Function mostra "Encerrado automaticamente"',
        (tester) async {
      await _abrir(
        tester,
        evento: Stream.value(_evento(
          inicioEm: const Duration(hours: -3),
          endedAt: _agora.subtract(const Duration(hours: 1)),
          endedAutomatically: true,
        )),
        quem: _visitante,
      );

      expect(
          find.text(AppStrings.eventStatusEndedAutomatically), findsOneWidget);
    });

    testWidgets('fim previsto + 1h passou: encerrado mesmo sem endedAt',
        (tester) async {
      await _abrir(
        tester,
        evento: Stream.value(_evento(inicioEm: const Duration(hours: -3))),
        quem: _visitante,
      );

      expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);
      expect(find.text(AppStrings.eventAlreadyEnded), findsOneWidget);
    });
  });

  testWidgets('um encerramento aparece sem recarregar', (tester) async {
    final documento = StreamController<Event?>();
    addTearDown(documento.close);
    final aoVivo = _evento(inicioEm: const Duration(minutes: -20));

    // O controller guarda o primeiro valor até a tela se inscrever.
    documento.add(aoVivo);
    await _abrir(tester, evento: documento.stream, quem: _visitante);
    expect(find.text(AppStrings.eventStatusLive), findsOneWidget);

    documento.add(aoVivo.copyWith(endedAt: _agora));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);
    expect(find.text(AppStrings.eventAlreadyEnded), findsOneWidget);
  });
}

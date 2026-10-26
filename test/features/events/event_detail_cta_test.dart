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
import 'package:mvp_compy/shared/widgets/event_skill_level_chip.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/ratings/presentation/providers/ratings_providers.dart';

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
  SkillLevel skillLevel = SkillLevel.todos,
}) =>
    Event(
      id: 'evt_detalhe',
      title: 'Rachão',
      sport: Sport.basquete,
      location: 'Parque do Trabalhador, Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: _agora.add(inicioEm),
      durationMinutes: 60,
      skillLevel: skillLevel,
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
  RatingSummary nota = RatingSummary.empty,
}) async {
  // Tela alta: a lista do detalhe só constrói o que aparece.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(_EventoAoVivo(evento)),
      ratingSummaryProvider.overrideWith(
        (ref, target) => Stream<RatingSummary>.value(nota),
      ),
    ],
    child: const MaterialApp(home: EventDetailPage(eventId: 'evt_detalhe')),
  ));
  await tester.pumpAndSettle();
}

Finder _botao(String label) => find.widgetWithText(FilledButton, label);

void main() {
  // O detalhe escreve o dia da semana em pt_BR, como o main.dart prepara.
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('detalhe explicita Todos os níveis', (tester) async {
    await _abrir(tester, evento: Stream.value(_evento()), quem: _visitante);
    expect(
        find.text('${AppStrings.eventSkillLevel}: '
            '${AppStrings.eventAllSkillLevels}'),
        findsOneWidget);
    expect(
        tester
            .widget<EventSkillLevelChip>(find.byType(EventSkillLevelChip))
            .level,
        SkillLevel.todos);
  });

  testWidgets('detalhe mostra o nível intermediário do evento', (tester) async {
    await _abrir(tester,
        evento: Stream.value(_evento(skillLevel: SkillLevel.intermediario)),
        quem: _visitante);
    expect(
        find.text('${AppStrings.eventSkillLevel}: '
            '${SkillLevel.intermediario.label}'),
        findsOneWidget);
    expect(
        tester
            .widget<EventSkillLevelChip>(find.byType(EventSkillLevelChip))
            .level,
        SkillLevel.intermediario);
  });

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
    final encerrado = _evento(
      inicioEm: const Duration(hours: -2),
      endedAt: _agora.subtract(const Duration(minutes: 50)),
    );

    testWidgets('quem não participou vê o selo e nenhuma ação', (tester) async {
      await _abrir(tester, evento: Stream.value(encerrado), quem: _visitante);

      expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);
      expect(find.text(AppStrings.eventAlreadyEnded), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('o participante vê "Avaliar evento"', (tester) async {
      await _abrir(tester,
          evento: Stream.value(encerrado), quem: _participante);

      expect(find.text(AppStrings.eventStatusEnded), findsOneWidget);
      expect(_botao(AppStrings.eventRate), findsOneWidget);
    });

    testWidgets('o criador vê "Avaliar local e participantes" (D14)',
        (tester) async {
      await _abrir(tester, evento: Stream.value(encerrado), quem: _dono);

      expect(_botao(AppStrings.eventRateAsCreator), findsOneWidget);
      expect(_botao(AppStrings.eventRate), findsNothing);
    });

    testWidgets('mostra a "Nota do evento" quando ele já tem notas',
        (tester) async {
      await _abrir(
        tester,
        evento: Stream.value(encerrado),
        quem: _visitante,
        nota: RatingSummary.fromAggregate(
          count: 8,
          sum: 37,
          starCounts: const <int, int>{5: 5, 4: 2, 3: 1},
        ),
      );

      expect(find.text(AppStrings.eventRatingAverage), findsOneWidget);
      expect(find.text('4,6'), findsOneWidget);
      expect(find.text('· 8 avaliações'), findsOneWidget);
    });

    testWidgets('sem notas, nada de "Nota do evento"', (tester) async {
      await _abrir(tester, evento: Stream.value(encerrado), quem: _visitante);

      expect(find.text(AppStrings.eventRatingAverage), findsNothing);
    });

    testWidgets('quem já avaliou vê "Você já avaliou"', (tester) async {
      await _abrir(
        tester,
        evento: Stream.value(
          encerrado.copyWith(ratedBy: const <String>['u_participante']),
        ),
        quem: _participante,
      );

      expect(find.text(AppStrings.eventAlreadyRated), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
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

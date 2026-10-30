import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_status.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/event_card.dart';
import 'package:mvp_compy/shared/widgets/event_skill_level_chip.dart';

Event _event({DateTime? start, int duration = 120, int spots = 3}) => Event(
      id: 'evento-real',
      title: 'Treino de tênis de mesa para todos os moradores do bairro',
      sport: Sport.tenisDeMesa,
      location: 'Ginásio Municipal de Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: start ?? DateTime(2026, 10, 31, 15),
      durationMinutes: duration,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: spots,
      bannerUrl: '',
      creator: const UserSummary(
          id: 'u', name: 'Ana', handle: '@ana', avatarUrl: ''),
    );

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onOpen,
  VoidCallback? onAction,
  Event? event,
  String label = AppStrings.eventJoin,
  bool disableWhenFull = true,
  EventStatus? status,
  Size size = const Size(390, 740),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
        body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: EventCard(
          event: event ?? _event(),
          actionLabel: label,
          onOpen: onOpen,
          onAction: onAction,
          disableWhenFull: disableWhenFull,
          status: status),
    )),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openCalendar(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppStrings.eventDateTimeTitle));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
}

List<SemanticsNode> _tapNodes(SemanticsNode root) {
  final result = <SemanticsNode>[];
  void collect(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(SemanticsAction.tap)) {
      result.add(node);
    }
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(root);
  return result;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
      'título, modalidade, imagem, local, nível e espaço livre abrem uma vez',
      (tester) async {
    var opens = 0;
    await _pump(tester, onOpen: () => opens++);
    final regions = [
      find.text(_event().title),
      find.text(Sport.tenisDeMesa.label),
      find.byType(CachedNetworkImage),
      find.textContaining(_event().location),
      find.byType(EventSkillLevelChip)
    ];
    for (var i = 0; i < regions.length; i++) {
      await tester.tap(regions[i]);
      await tester.pumpAndSettle();
      expect(opens, i + 1);
    }
    final card =
        tester.getRect(find.byKey(const ValueKey('event-card-evento-real')));
    await tester.tapAt(card.bottomRight - const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(opens, 6);
  });

  for (final label in [AppStrings.eventJoin, AppStrings.eventSeeMore]) {
    testWidgets('$label mantém a navegação, com um único disparo',
        (tester) async {
      var opens = 0;
      await _pump(tester, onOpen: () => opens++, label: label);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(opens, 1);
    });
  }

  testWidgets('CTA com ação específica não dispara o corpo do card',
      (tester) async {
    var opens = 0;
    var actions = 0;
    await _pump(tester, onOpen: () => opens++, onAction: () => actions++);
    await tester.tap(find.text(AppStrings.eventJoin));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(opens, 0);
    await tester.tap(find.text(_event().title));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(opens, 1);
  });

  testWidgets(
      'calendário só mostra os dados reais, sem navegar ou executar CTA',
      (tester) async {
    var opens = 0;
    var actions = 0;
    final event = _event();
    final snapshot = event.toMap();
    await _pump(tester,
        onOpen: () => opens++, onAction: () => actions++, event: event);
    final target =
        tester.getSize(find.byTooltip(AppStrings.eventDateTimeTitle));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    await _openCalendar(tester);
    expect(find.text('Sábado, 31 de outubro de 2026'), findsOneWidget);
    expect(find.text('Início: 15:00'), findsOneWidget);
    expect(find.text('Término previsto: 17:00'), findsOneWidget);
    expect(find.text('Duração: 2h'), findsOneWidget);
    expect(opens, 0);
    expect(actions, 0);
    await tester.tap(find.byTooltip(AppStrings.commonClose));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(event.toMap(), snapshot);
    expect(opens, 0);
    expect(actions, 0);
  });

  testWidgets('folha fecha pela barreira e pelo voltar sem navegar',
      (tester) async {
    var opens = 0;
    await _pump(tester, onOpen: () => opens++);
    await _openCalendar(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await _openCalendar(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(opens, 0);
  });

  testWidgets('lotado bloqueia apenas CTA; corpo e calendário continuam ativos',
      (tester) async {
    var opens = 0;
    await _pump(tester, onOpen: () => opens++, event: _event(spots: 0));
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    await tester.tap(find.text(AppStrings.eventCardFull));
    await tester.pumpAndSettle();
    expect(opens, 0);
    await tester.tap(find.text(_event().title));
    await tester.pumpAndSettle();
    expect(opens, 1);
    await _openCalendar(tester);
    expect(opens, 1);
  });

  testWidgets('Ver mais em evento pessoal lotado permanece habilitado',
      (tester) async {
    var opens = 0;
    await _pump(tester,
        onOpen: () => opens++,
        event: _event(spots: 0),
        label: AppStrings.eventSeeMore,
        disableWhenFull: false);
    await tester.tap(find.text(AppStrings.eventSeeMore));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('término mostra a data seguinte inclusive na virada do ano',
      (tester) async {
    await _pump(tester,
        onOpen: () {},
        event: _event(start: DateTime(2026, 12, 31, 23, 30), duration: 90));
    await _openCalendar(tester);
    expect(find.text('Quinta-feira, 31 de dezembro de 2026'), findsOneWidget);
    expect(find.text('Início: 23:30'), findsOneWidget);
    expect(find.text('Término previsto: 01:00'), findsOneWidget);
    expect(find.text('sexta-feira, 1 de janeiro de 2027'), findsOneWidget);
    expect(find.text('Duração: 1h30'), findsOneWidget);
  });

  testWidgets('instante UTC é apresentado no horário local', (tester) async {
    await _pump(tester,
        onOpen: () {},
        event: _event(start: DateTime(2026, 10, 31, 15).toUtc(), duration: 45));
    await _openCalendar(tester);
    expect(find.text('Sábado, 31 de outubro de 2026'), findsOneWidget);
    expect(find.text('Início: 15:00'), findsOneWidget);
    expect(find.text('Término previsto: 15:45'), findsOneWidget);
    expect(find.text('Duração: 45min'), findsOneWidget);
  });

  testWidgets('legado sem duração usa o padrão do modelo', (tester) async {
    final data = _event().toMap()
      ..remove('durationMinutes')
      ..remove('endsAt');
    final legacy = Event.fromMap('evento-real', data);
    await _pump(tester, onOpen: () {}, event: legacy);
    await _openCalendar(tester);
    expect(find.text('Término previsto: 16:00'), findsOneWidget);
    expect(find.text('Duração: 1h'), findsOneWidget);
  });

  testWidgets('tela estreita e texto ampliado não causam overflow',
      (tester) async {
    await _pump(tester,
        onOpen: () {}, size: const Size(280, 480), textScale: 1.5);
    await _openCalendar(tester);
    expect(find.text('Sábado, 31 de outubro de 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(AppStrings.commonClose));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('acontecendo mantém selo e navegação sem calendário',
      (tester) async {
    var opens = 0;
    await _pump(tester, onOpen: () => opens++, status: EventStatus.happening);
    expect(find.text(AppStrings.eventStatusLive), findsOneWidget);
    expect(find.byTooltip(AppStrings.eventDateTimeTitle), findsNothing);
    await tester.tap(find.text(AppStrings.eventStatusLive));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets(
      'semântica oferece um detalhe e um calendário, sem CTA redundante',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var opens = 0;
    await _pump(tester, onOpen: () => opens++);
    final root = tester
        .getSemantics(find.byKey(const ValueKey('event-card-evento-real')));
    expect(_tapNodes(root), hasLength(2));
    root.owner!.performAction(root.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(opens, 1);
    semantics.dispose();
  });
}

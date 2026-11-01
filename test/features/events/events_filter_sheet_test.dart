import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/events/presentation/widgets/events_filter_sheet.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';

void main() {
  // A folha é aberta por um botão qualquer — sem router, porque só o
  // caminho vindo da Home navega depois de aplicar.
  // A viewport padrão (800x600) corta a folha e os chips de nível nem
  // chegam a ser construídos — o teste ganha uma tela alta para poder
  // tocar em qualquer critério sem rolar.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    useTallViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEventsFilterSheet(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a folha lista todas as modalidades do enum', (tester) async {
    await pumpSheet(tester);

    for (final sport in Sport.values) {
      expect(
        find.text(sport.label),
        findsWidgets,
        reason: '${sport.label} precisa estar alcançável pelo seletor',
      );
    }
  });

  // Issue 30: com 16 modalidades a grade ocupa quatro fileiras. A folha não
  // passa de 85% da tela e rola por dentro; num aparelho pequeno (360x640
  // lógicos), o último esporte precisa continuar alcançável e o "Aplicar",
  // fixo embaixo, à vista.
  for (final double escala in <double>[1, 1.3]) {
    testWidgets(
        'em tela pequena com fonte ${escala}x a folha rola até o último '
        'esporte, sem overflow', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showEventsFilterSheet(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final ultimo = Sport.values.last;
      await tester.ensureVisible(find.text(ultimo.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ultimo.label));
      await tester.pump();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(eventsFilterProvider).sport, ultimo);
    });
  }

  testWidgets('escolher modalidade e aplicar publica o filtro',
      (tester) async {
    final container = await pumpSheet(tester);
    expect(container.read(eventsFilterProvider).isEmpty, isTrue);

    await tester.tap(find.text(Sport.corrida.label));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(container.read(eventsFilterProvider).sport, Sport.corrida);
  });

  testWidgets('nível de habilidade entra no filtro junto da modalidade',
      (tester) async {
    final container = await pumpSheet(tester);

    await tester.tap(find.text(Sport.volei.label));
    await tester.pump();
    await tester.tap(find.text(SkillLevel.iniciante.label));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final filter = container.read(eventsFilterProvider);
    expect(filter.sport, Sport.volei);
    expect(filter.skillLevel, SkillLevel.iniciante);
  });

  testWidgets('"Todos" não é oferecido — ausência de nível já é qualquer nível',
      (tester) async {
    await pumpSheet(tester);
    expect(find.text(SkillLevel.todos.label), findsNothing);
  });

  testWidgets('tocar de novo na modalidade marcada desmarca', (tester) async {
    final container = await pumpSheet(tester);

    await tester.tap(find.text(Sport.futsal.label));
    await tester.pump();
    await tester.tap(find.text(Sport.futsal.label));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(container.read(eventsFilterProvider).isEmpty, isTrue);
  });

  testWidgets('"Limpar tudo" zera o rascunho', (tester) async {
    useTallViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(eventsFilterProvider.notifier).state = const EventsFilter(
      sport: Sport.basquete,
      skillLevel: SkillLevel.avancado,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEventsFilterSheet(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpar tudo'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(container.read(eventsFilterProvider).isEmpty, isTrue);
  });
}

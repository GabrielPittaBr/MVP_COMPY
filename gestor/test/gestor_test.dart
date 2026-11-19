import 'package:compy_gestor/app.dart';
import 'package:compy_gestor/core/theme/gestor_colors.dart';
import 'package:compy_gestor/core/theme/venue_theme.dart';
import 'package:compy_gestor/features/agenda/domain/agenda.dart';
import 'package:compy_gestor/features/agenda/presentation/agenda_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste WCAG 2.x entre duas cores.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

void main() {
  test('os seis temas passam no contraste AA da tabela de temas', () {
    for (final t in VenueTheme.values) {
      expect(
        _contrast(t.ink, t.floor),
        greaterThanOrEqualTo(4.5),
        reason: '${t.label}: texto',
      );
      expect(
        _contrast(t.accent, t.floor),
        greaterThanOrEqualTo(3),
        reason: '${t.label}: destaque',
      );
      expect(
        _contrast(t.ink, t.selected),
        greaterThanOrEqualTo(8),
        reason: '${t.label}: selecionado',
      );
    }
  });

  test('cores de estado da agenda têm texto legível (4,5:1)', () {
    for (final (fg, bg) in const [
      (GestorColors.primary, GestorColors.primaryContainer),
      (GestorColors.onWarningContainer, GestorColors.warningContainer),
      (GestorColors.onSurfaceVariant, GestorColors.surfaceContainer),
      (GestorColors.onSecondaryContainer, GestorColors.secondaryContainer),
      (GestorColors.onErrorContainer, GestorColors.errorContainer),
    ]) {
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    }
  });

  group('agenda sem conflito', () {
    late ProviderContainer container;
    late AgendaController agenda;

    setUp(() {
      container = ProviderContainer();
      agenda = container.read(agendaProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('não reserva quadra ocupada e reserva a livre', () {
      // Quadra 1 às 19h é do Paulo; a Quadra 2 às 22h está livre.
      expect(
        agenda.book(
          court: 1,
          day: 0,
          start: 19 * 60,
          end: 20 * 60,
          name: 'Rafa',
          source: Source.whatsapp,
        ),
        contains('já está ocupada'),
      );
      expect(
        agenda.book(
          court: 2,
          day: 0,
          start: 22 * 60,
          end: 23 * 60,
          name: 'Rafa',
          source: Source.whatsapp,
        ),
        isNull,
      );
      expect(
        container.read(agendaProvider).at(2, 0, 22 * 60, 23 * 60)?.kind,
        ItemKind.reserva,
      );
    });

    test('reservar um horário publicado tira ele do app', () {
      agenda.book(
        court: 4,
        day: 0,
        start: 22 * 60,
        end: 23 * 60,
        name: 'Fer',
        source: Source.balcao,
      );
      final items = container.read(agendaProvider).dayItems(0);
      expect(
        items.where((i) => i.court == 4 && i.kind == ItemKind.horarioLivre),
        isEmpty,
      );
    });

    test(
      'bloqueio não passa por cima de reserva e pula o que já está ocupado',
      () {
        expect(
          agenda.block(
            courts: [1],
            day: 0,
            start: 19 * 60,
            end: 21 * 60,
            reason: 'Chuva',
          ),
          contains('Mova ou cancele'),
        );
        // Quadra 3, 21h às 23h: às 21h ela já está bloqueada para
        // manutenção, então só as 22h viram "Aula".
        expect(
          agenda.block(
            courts: [3],
            day: 0,
            start: 21 * 60,
            end: 23 * 60,
            reason: 'Aula',
          ),
          isNull,
        );
        final blocks = container
            .read(agendaProvider)
            .dayItems(0)
            .where(
              (i) =>
                  i.court == 3 &&
                  i.kind == ItemKind.bloqueio &&
                  i.title == 'Aula',
            )
            .toList();
        expect(blocks.single.start, 22 * 60);
      },
    );

    test('confirmar a solicitação soma as horas recuperadas', () {
      final before = container.read(agendaProvider).recoveredHours;
      agenda.confirm('req-marina');
      final state = container.read(agendaProvider);
      expect(state.recoveredHours, before + 1);
      expect(state.byId('req-marina')?.kind, ItemKind.reserva);
    });
  });

  testWidgets('atendente entra pelo convite e confirma uma solicitação', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: GestorApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar com Google'));
    await tester.pumpAndSettle();
    expect(find.text('Responder agora'), findsOneWidget);
    expect(find.text('Marina Souza'), findsOneWidget);

    await tester.tap(find.text('Confirmar').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Reserva confirmada'), findsOneWidget);
    expect(find.text('Marina Souza'), findsNothing);
  });
}

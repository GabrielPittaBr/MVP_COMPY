import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/utils/day_label.dart';

void main() {
  // `now` fixo para o teste não depender do relógio de quem roda.
  final now = DateTime(2026, 8, 9, 14, 30);

  group('DayLabel.of', () {
    test('mesmo dia vira "Hoje", em qualquer hora', () {
      expect(DayLabel.of(DateTime(2026, 8, 9, 0, 1), now: now), 'Hoje');
      expect(DayLabel.of(DateTime(2026, 8, 9, 23, 59), now: now), 'Hoje');
    });

    test('dia anterior vira "Ontem"', () {
      expect(DayLabel.of(DateTime(2026, 8, 8, 23, 59), now: now), 'Ontem');
      expect(DayLabel.of(DateTime(2026, 8, 8, 0, 0), now: now), 'Ontem');
    });

    test('mais antigo mostra a data', () {
      expect(DayLabel.of(DateTime(2026, 8, 7, 20), now: now), '07/08/2026');
      expect(DayLabel.of(DateTime(2025, 12, 31), now: now), '31/12/2025');
    });

    test('atravessa a virada do mês e do ano', () {
      final primeiroDeMarco = DateTime(2026, 3, 1, 9);
      expect(
        DayLabel.of(DateTime(2026, 2, 28, 22), now: primeiroDeMarco),
        'Ontem',
      );

      final anoNovo = DateTime(2026, 1, 1, 9);
      expect(DayLabel.of(DateTime(2025, 12, 31, 22), now: anoNovo), 'Ontem');
    });

    test('data futura não é tratada como ontem', () {
      expect(DayLabel.of(DateTime(2026, 8, 10, 9), now: now), '10/08/2026');
    });
  });

  group('DayLabel.isSameDay', () {
    test('compara só a data, ignorando a hora', () {
      expect(
        DayLabel.isSameDay(DateTime(2026, 8, 9, 1), DateTime(2026, 8, 9, 23)),
        isTrue,
      );
      expect(
        DayLabel.isSameDay(DateTime(2026, 8, 9, 23), DateTime(2026, 8, 10, 0)),
        isFalse,
      );
    });
  });
}

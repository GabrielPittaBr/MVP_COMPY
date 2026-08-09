import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/utils/duration_format.dart';

void main() {
  group('DurationFormat.short', () {
    test('abaixo de 1h mostra só minutos', () {
      expect(DurationFormat.short(30), '30min');
      expect(DurationFormat.short(45), '45min');
    });

    test('horas cheias não mostram minutos', () {
      expect(DurationFormat.short(60), '1h');
      expect(DurationFormat.short(120), '2h');
      expect(DurationFormat.short(180), '3h');
    });

    test('horas quebradas mostram os minutos com dois dígitos', () {
      expect(DurationFormat.short(90), '1h30');
      expect(DurationFormat.short(65), '1h05');
      expect(DurationFormat.short(135), '2h15');
    });

    test('duração inválida não quebra a tela', () {
      expect(DurationFormat.short(0), '0min');
      expect(DurationFormat.short(-10), '0min');
    });
  });

  group('DurationFormat.timeRange', () {
    test('monta o intervalo em 24h', () {
      final start = DateTime(2026, 8, 9, 15);
      expect(DurationFormat.timeRange(start, 60), '15:00 – 16:00');
      expect(DurationFormat.timeRange(start, 90), '15:00 – 16:30');
    });

    test('atravessa a virada do dia', () {
      final start = DateTime(2026, 8, 9, 23, 30);
      expect(DurationFormat.timeRange(start, 60), '23:30 – 00:30');
    });
  });
}

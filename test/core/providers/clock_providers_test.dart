import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';

void main() {
  test('nowProvider emite primeiro o instante do relógio', () async {
    final fixo = DateTime(2026, 10, 21, 19, 30);
    final container = ProviderContainer(
      overrides: <Override>[clockProvider.overrideWithValue(() => fixo)],
    );
    addTearDown(container.dispose);

    expect(await container.read(nowProvider.future), fixo);
  });

  test('os dois aceitam valor fixo nos testes', () async {
    final fixo = DateTime(2026, 10, 21, 8);
    final container = ProviderContainer(
      overrides: <Override>[
        clockProvider.overrideWithValue(() => fixo),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(fixo)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider)(), fixo);
    expect(await container.read(nowProvider.future), fixo);
  });
}

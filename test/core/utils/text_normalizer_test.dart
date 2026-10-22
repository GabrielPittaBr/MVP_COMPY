import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/utils/text_normalizer.dart';

void main() {
  test('normaliza texto pt-BR para busca por prefixo', () {
    expect(TextNormalizer.normalize('  João Çarvalho  '), 'joao carvalho');
  });
}

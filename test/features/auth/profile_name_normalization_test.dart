import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  test('perfil novo usa o normalizador pt-BR aprovado em nameLower', () {
    expect(AuthRemoteDataSource.normalizeProfileName('  Vôlei do João  '), 'volei do joao');
  });
}

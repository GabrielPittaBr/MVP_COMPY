import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/data/datasources/auth_remote_datasource.dart';

/// O documento de `usernames` é chaveado pelo username (`joao`), enquanto o
/// perfil guarda o handle (`@joao`). Se a conversão errar, a exclusão de conta
/// deixa a reserva do nome para trás — e ninguém mais consegue usá-lo, porque
/// o `update` da regra exige ser do mesmo uid, que já não existe.
void main() {
  String? docId(String? handle) =>
      AuthRemoteDataSource.usernameDocIdFromHandle(handle);

  group('usernameDocIdFromHandle', () {
    test('tira o @ do handle', () {
      expect(docId('@joao'), 'joao');
    });

    test('normaliza para minúsculo, como na gravação', () {
      expect(docId('@JoAo.Silva'), 'joao.silva');
    });

    test('tolera espaço em volta', () {
      expect(docId('  @joao  '), 'joao');
    });

    test('aceita handle já sem @', () {
      expect(docId('joao'), 'joao');
    });

    // Nestes casos não há documento a apagar, e pedir a exclusão de um doc
    // inexistente derrubaria o batch inteiro: a regra olha `resource.data.uid`
    // e `resource` é nulo.
    test('devolve null quando não há handle utilizável', () {
      expect(docId(null), isNull);
      expect(docId(''), isNull);
      expect(docId('   '), isNull);
      expect(docId('@'), isNull);
    });
  });
}

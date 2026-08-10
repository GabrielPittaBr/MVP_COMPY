import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  group('AuthRemoteDataSource.usernameAvailableFor', () {
    test('username livre está disponível para qualquer um', () {
      expect(
        AuthRemoteDataSource.usernameAvailableFor(existing: null),
        isTrue,
      );
      expect(
        AuthRemoteDataSource.usernameAvailableFor(
          existing: null,
          forUid: 'uid_gabriel',
        ),
        isTrue,
      );
    });

    test('username de outro usuário está indisponível', () {
      expect(
        AuthRemoteDataSource.usernameAvailableFor(
          existing: <String, dynamic>{'uid': 'uid_outro'},
          forUid: 'uid_gabriel',
        ),
        isFalse,
      );
    });

    // O bug que esta função existe para matar: quem era mandado de volta
    // para /username por uma leitura de perfil que falhou levava
    // "username já em uso" no username dele mesmo, e não saía da tela.
    test('o próprio username continua disponível para o dono', () {
      expect(
        AuthRemoteDataSource.usernameAvailableFor(
          existing: <String, dynamic>{'uid': 'uid_gabriel'},
          forUid: 'uid_gabriel',
        ),
        isTrue,
      );
    });

    test('sem uid esperado, qualquer documento existente bloqueia', () {
      // É o cadastro por e-mail: a conta ainda não existe, então não há dono
      // possível para o documento encontrado.
      expect(
        AuthRemoteDataSource.usernameAvailableFor(
          existing: <String, dynamic>{'uid': 'uid_gabriel'},
        ),
        isFalse,
      );
    });

    test('documento sem uid não é reivindicável por ninguém', () {
      expect(
        AuthRemoteDataSource.usernameAvailableFor(
          existing: <String, dynamic>{},
          forUid: 'uid_gabriel',
        ),
        isFalse,
      );
    });
  });
}

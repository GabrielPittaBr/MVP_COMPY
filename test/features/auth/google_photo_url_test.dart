import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/data/datasources/auth_remote_datasource.dart';

/// A foto do Google chega pequena demais para o círculo do perfil; o sufixo
/// de tamanho é trocado para pedir uma maior ao próprio Google.
void main() {
  String? large(String? url) => AuthRemoteDataSource.largeGooglePhoto(url);

  group('largeGooglePhoto', () {
    test('troca o sufixo de 96 px por 400 px', () {
      expect(
        large('https://lh3.googleusercontent.com/a/ACg8ocJx=s96-c'),
        'https://lh3.googleusercontent.com/a/ACg8ocJx=s400-c',
      );
    });

    test('URL sem sufixo de tamanho passa intacta', () {
      const String url = 'https://lh3.googleusercontent.com/a-/foto.jpg';
      expect(large(url), url);
    });

    test('conta sem foto continua sem foto', () {
      expect(large(null), isNull);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de configuração do `google-services.json`.
///
/// Não reproduz a falha em runtime — reproduzir exigiria o seletor de conta do
/// Google num aparelho. Ele trava a **pré-condição** cuja violação derrubou o
/// login com Google: o arquivo voltar do `flutterfire configure` com
/// `oauth_client` vazio, o que acontece quando a SHA-1 do keystore não está
/// cadastrada no Firebase Console. O sintoma é `ApiException: 10`
/// (DEVELOPER_ERROR), sem nenhuma pista na tela.
///
/// O arquivo é gitignored, então em máquina sem ele o teste é pulado — a
/// falha só interessa em quem vai de fato compilar o app.
void main() {
  final file = File('android/app/google-services.json');

  group('google-services.json', () {
    test('tem cliente OAuth para o login com Google', () {
      if (!file.existsSync()) {
        markTestSkipped(
          'android/app/google-services.json ausente (gitignored) — '
          'rode `flutterfire configure`.',
        );
        return;
      }

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final clients = (json['client'] as List<dynamic>).cast<Map<String, dynamic>>();

      expect(clients, isNotEmpty, reason: 'nenhum app Android no arquivo');

      for (final client in clients) {
        final info = client['client_info'] as Map<String, dynamic>;
        final androidInfo = info['android_client_info'] as Map<String, dynamic>;
        final package = androidInfo['package_name'] as String;
        final oauthClients =
            (client['oauth_client'] as List<dynamic>? ?? <dynamic>[]);

        expect(
          oauthClients,
          isNotEmpty,
          reason:
              'O pacote $package está sem `oauth_client`. O login com Google '
              'vai falhar com ApiException: 10 (DEVELOPER_ERROR) em todo '
              'aparelho. Cadastre a SHA-1 do keystore no Firebase Console e '
              'baixe o google-services.json de novo.',
        );
      }
    });
  });
}

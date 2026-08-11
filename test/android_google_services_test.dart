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
///
/// O `applicationId` é lido do `build.gradle.kts` em vez de escrito aqui de
/// novo: o arquivo lista **todos** os apps Android do projeto Firebase, e
/// `compy-tcc` ainda carrega o registro antigo `com.example.mvp_compy`. Um
/// teste que só varresse a lista continuaria verde com o app apontando para o
/// pacote errado — exatamente o engano que a troca de pacote pode introduzir.
void main() {
  final file = File('android/app/google-services.json');
  final gradle = File('android/app/build.gradle.kts');

  group('google-services.json', () {
    test('tem cliente OAuth para o login com Google', () {
      if (!file.existsSync()) {
        markTestSkipped(
          'android/app/google-services.json ausente (gitignored) — '
          'rode `flutterfire configure`.',
        );
        return;
      }

      final applicationId = RegExp(r'applicationId\s*=\s*"([^"]+)"')
          .firstMatch(gradle.readAsStringSync())
          ?.group(1);
      expect(
        applicationId,
        isNotNull,
        reason: 'não achei o applicationId em android/app/build.gradle.kts',
      );

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final clients =
          (json['client'] as List<dynamic>).cast<Map<String, dynamic>>();

      Map<String, dynamic>? mine;
      for (final client in clients) {
        final info = client['client_info'] as Map<String, dynamic>;
        final androidInfo = info['android_client_info'] as Map<String, dynamic>;
        if (androidInfo['package_name'] == applicationId) mine = client;
      }

      expect(
        mine,
        isNotNull,
        reason:
            'O google-services.json não tem nenhum cliente para $applicationId. '
            'O app não vai nem inicializar o Firebase. Registre o pacote no '
            'projeto e baixe o arquivo de novo.',
      );

      expect(
        (mine!['oauth_client'] as List<dynamic>? ?? <dynamic>[]),
        isNotEmpty,
        reason:
            'O pacote $applicationId está sem `oauth_client`. O login com '
            'Google vai falhar com ApiException: 10 (DEVELOPER_ERROR) em todo '
            'aparelho. Cadastre a SHA-1 do keystore no Firebase Console e '
            'baixe o google-services.json de novo.',
      );
    });
  });
}

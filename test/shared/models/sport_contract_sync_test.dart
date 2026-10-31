import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/sport.dart';

/// A lista de modalidades está copiada fora do app: nas regras do Firestore,
/// no painel admin e nas ferramentas do Admin SDK. Se uma cópia ficar para
/// trás, algo quebra sem aviso — o admin não salva o local com o esporte novo,
/// ou o painel mostra o nome cru. Este teste lê as três cópias como texto e
/// compara com o enum, que é a fonte (issue 30).
///
/// Roda a partir da raiz do repositório, que é onde o `flutter test` roda.
void main() {
  final List<String> nomes =
      Sport.values.map((Sport s) => s.storageName).toList();

  String trecho(String fonte, String inicio, String fim) {
    final int i = fonte.indexOf(inicio);
    expect(i, isNot(-1), reason: 'não achei "$inicio"');
    final int j = fonte.indexOf(fim, i + inicio.length);
    expect(j, isNot(-1), reason: 'não achei "$fim" depois de "$inicio"');
    return fonte.substring(i + inicio.length, j);
  }

  List<String> entreAspas(String bloco) => RegExp(r"'([A-Za-z]+)'")
      .allMatches(bloco)
      .map((RegExpMatch m) => m.group(1)!)
      .toList();

  test('firestore.rules aceita as modalidades do enum, com o mesmo limite', () {
    final String regras = File('firestore.rules').readAsStringSync();
    final String lista = trecho(
      regras,
      'request.resource.data.sports.toSet().hasOnly(',
      ')',
    );

    expect(entreAspas(lista), nomes);
    expect(
      regras,
      contains('request.resource.data.sports.size() <= ${nomes.length}'),
    );
    expect(
      regras,
      contains(
        'request.resource.data.favoriteSports.size() <= ${nomes.length}',
      ),
    );
  });

  test('painel admin tem os mesmos nomes e os mesmos rótulos do app', () {
    final String fonte =
        File('admin/lib/core/constants/admin_sports.dart').readAsStringSync();
    final String mapa = trecho(
      fonte,
      'adminSportLabels = <String, String>{',
      '};',
    );
    final Map<String, String> rotulos = <String, String>{
      for (final RegExpMatch m
          in RegExp(r"'([A-Za-z]+)': '([^']+)'").allMatches(mapa))
        m.group(1)!: m.group(2)!,
    };

    expect(rotulos.keys.toList(), nomes);
    for (final Sport sport in Sport.values) {
      expect(rotulos[sport.storageName], sport.label, reason: sport.name);
    }
  });

  test('Admin SDK aceita as modalidades do enum, na mesma ordem', () {
    final String fonte =
        File('tools/firebase-admin/src/places/place_contract.ts')
            .readAsStringSync();
    final String lista = trecho(
      fonte,
      'export const supportedSports = [',
      ']',
    );

    expect(entreAspas(lista), nomes);
  });
}

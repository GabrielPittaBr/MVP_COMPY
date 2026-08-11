import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

void main() {
  group('SportPlace.byId', () {
    test('acha o local do catálogo pelo id', () {
      // É assim que o local viaja do pin do mapa para o formulário de
      // criação: pelo id, via `extra` do GoRouter.
      expect(
        SportPlace.byId('parque_do_trabalhador'),
        SportPlace.parqueDoTrabalhador,
      );
    });

    test('devolve null para id desconhecido', () {
      expect(SportPlace.byId('local_que_nao_existe'), isNull);
      expect(SportPlace.byId(''), isNull);
    });

    test('todo id do catálogo é resolvível', () {
      for (final place in SportPlace.all) {
        expect(SportPlace.byId(place.id), place, reason: place.id);
      }
    });
  });
}

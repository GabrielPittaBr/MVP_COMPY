import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/sport.dart';

void main() {
  group('Sport.tryParse', () {
    test('nome persistido volta a ser o enum', () {
      expect(Sport.tryParse('futebol'), Sport.futebol);
      expect(Sport.tryParse('tenisDeMesa'), Sport.tenisDeMesa);
    });

    test('nome desconhecido devolve null em vez de estourar', () {
      expect(Sport.tryParse('parkour'), isNull);
      expect(Sport.tryParse(''), isNull);
    });

    test('valor que não é string devolve null', () {
      expect(Sport.tryParse(null), isNull);
      expect(Sport.tryParse(42), isNull);
      expect(Sport.tryParse(<String>['futebol']), isNull);
    });

    test('o label não serve como chave — só o nome do enum', () {
      expect(Sport.tryParse('Tênis de mesa'), isNull);
      expect(Sport.tryParse('Futebol'), isNull);
    });
  });

  group('Sport.parseList', () {
    test('array persistido vira a lista de esportes, na ordem gravada', () {
      expect(
        Sport.parseList(<Object?>['volei', 'futebol']),
        <Sport>[Sport.volei, Sport.futebol],
      );
    });

    test('nome desconhecido é descartado, os conhecidos sobrevivem', () {
      expect(
        Sport.parseList(<Object?>['futebol', 'parkour', 'corrida']),
        <Sport>[Sport.futebol, Sport.corrida],
      );
    });

    test('duplicata é descartada', () {
      expect(
        Sport.parseList(<Object?>['futebol', 'futebol']),
        <Sport>[Sport.futebol],
      );
    });

    test('campo ausente ou de tipo errado vira lista vazia, não erro', () {
      expect(Sport.parseList(null), isEmpty);
      expect(Sport.parseList('futebol'), isEmpty);
      expect(Sport.parseList(<Object?>[]), isEmpty);
    });
  });

  group('Sport.toStorage', () {
    test('ida e volta preserva a lista', () {
      const escolhidos = <Sport>[Sport.basquete, Sport.caminhada];
      expect(Sport.parseList(Sport.toStorage(escolhidos)), escolhidos);
    });

    test('todo esporte do enum sobrevive à ida e volta', () {
      expect(Sport.parseList(Sport.toStorage(Sport.values)), Sport.values);
    });
  });

  group('Sport.hasStoredFavorites', () {
    // O sinal do onboarding é a presença do campo, não a lista ter itens:
    // quem pula grava lista vazia e está pronto.
    test('campo ausente significa que o usuário nunca escolheu', () {
      expect(Sport.hasStoredFavorites(<String, dynamic>{'name': 'Gabriel'}), isFalse);
      expect(Sport.hasStoredFavorites(null), isFalse);
    });

    test('lista vazia conta como escolha registrada', () {
      expect(
        Sport.hasStoredFavorites(<String, dynamic>{'favoriteSports': <String>[]}),
        isTrue,
      );
    });

    test('lista com itens conta como escolha registrada', () {
      expect(
        Sport.hasStoredFavorites(<String, dynamic>{
          'favoriteSports': <String>['futebol'],
        }),
        isTrue,
      );
    });
  });
}

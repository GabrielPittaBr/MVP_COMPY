import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';

void main() {
  group('Conversation.idBetween', () {
    test('a ordem dos participantes não muda o id', () {
      // É o ponto todo: se os dois lados iniciarem a conversa ao mesmo tempo,
      // os dois têm que chegar no mesmo documento — senão viram duas conversas
      // com a mesma pessoa e o histórico se parte entre elas.
      expect(
        Conversation.idBetween('uid_joao', 'uid_douglas'),
        Conversation.idBetween('uid_douglas', 'uid_joao'),
      );
    });

    test('o id carrega os dois uids', () {
      final id = Conversation.idBetween('uid_joao', 'uid_douglas');

      expect(id, contains('uid_joao'));
      expect(id, contains('uid_douglas'));
    });

    test('pares diferentes geram ids diferentes', () {
      final comDouglas = Conversation.idBetween('uid_joao', 'uid_douglas');
      final comHercules = Conversation.idBetween('uid_joao', 'uid_hercules');

      expect(comDouglas, isNot(comHercules));
    });

    test('é estável entre chamadas', () {
      expect(
        Conversation.idBetween('uid_joao', 'uid_douglas'),
        Conversation.idBetween('uid_joao', 'uid_douglas'),
      );
    });

    test('conversa consigo mesmo não é permitida', () {
      expect(
        () => Conversation.idBetween('uid_joao', 'uid_joao'),
        throwsArgumentError,
      );
    });

    test('uid vazio não é permitido', () {
      expect(
        () => Conversation.idBetween('', 'uid_douglas'),
        throwsArgumentError,
      );
    });
  });
}

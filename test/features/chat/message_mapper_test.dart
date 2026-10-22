import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/data/mappers/message_mapper.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';

void main() {
  group('MessageMapper.fromMap', () {
    test('mapeia o documento do Firestore', () {
      final sentAt = DateTime(2026, 8, 9, 14, 30);
      final message =
          MessageMapper.fromMap('m1', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_douglas',
        'text': 'Bora treinar?',
        'sentAt': Timestamp.fromDate(sentAt),
      });

      expect(message.id, 'm1');
      expect(message.conversationId, 'c_douglas');
      expect(message.senderId, 'uid_douglas');
      expect(message.text, 'Bora treinar?');
      expect(message.sentAt, sentAt);
    });

    test('sentAt nulo (serverTimestamp pendente) vira agora, não a época zero',
        () {
      // O `serverTimestamp()` do envio só chega preenchido quando o servidor
      // confirma. No primeiro snapshot local ele vem nulo — se virasse epoch,
      // a mensagem recém-enviada saltaria para o topo do histórico.
      final before = DateTime.now();
      final message =
          MessageMapper.fromMap('m2', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Bora!',
        'sentAt': null,
      });
      final after = DateTime.now();

      expect(message.sentAt.isBefore(before), isFalse);
      expect(message.sentAt.isAfter(after), isFalse);
    });

    test('documento incompleto não quebra a sala', () {
      final message =
          MessageMapper.fromMap('m3', 'c_douglas', <String, dynamic>{});

      expect(message.senderId, '');
      expect(message.text, '');
      expect(message.sentAt, isNotNull);
    });

    test('mensagem de local carrega o id do local', () {
      final message =
          MessageMapper.fromMap('m4', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Encaminhou um local...',
        'placeId': 'parque_do_trabalhador',
        'placeSnapshot': <String, Object?>{
          'name': 'Parque do Trabalhador',
          'imageUrl': 'https://example.com/parque.jpg',
          'primarySport': 'futebol',
        },
      });

      expect(message.placeId, 'parque_do_trabalhador');
      expect(message.isPlace, isTrue);
      expect(message.placeSnapshot?.name, 'Parque do Trabalhador');
      expect(message.placeSnapshot?.primarySport.storageName, 'futebol');
    });

    test('mensagem placeId-only legada continua sem snapshot', () {
      final message =
          MessageMapper.fromMap('m4-old', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Encaminhou um local...',
        'placeId': 'parque_do_trabalhador',
      });

      expect(message.isPlace, isTrue);
      expect(message.placeSnapshot, isNull);
    });

    test('snapshot malformado é ignorado para preservar a leitura histórica',
        () {
      final message =
          MessageMapper.fromMap('m4-bad', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Encaminhou um local...',
        'placeId': 'parque_do_trabalhador',
        'placeSnapshot': <String, Object?>{
          'name': 'Parque',
          'imageUrl': 'http://inseguro.example/parque.jpg',
          'primarySport': 'futebol',
        },
      });

      expect(message.isPlace, isTrue);
      expect(message.placeSnapshot, isNull);
    });

    test('mensagem de texto não é mensagem de local', () {
      final message =
          MessageMapper.fromMap('m5', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Bora!',
      });

      expect(message.placeId, isNull);
      expect(message.isPlace, isFalse);
    });

    test('placeId vazio não vira card de local', () {
      final message =
          MessageMapper.fromMap('m6', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'Bora!',
        'placeId': '   ',
      });

      expect(message.isPlace, isFalse);
    });
  });

  group('MessageMapper.sortedBySentAt', () {
    Message at(String id, DateTime sentAt) => Message(
          id: id,
          conversationId: 'c_douglas',
          senderId: 'uid_joao',
          text: id,
          sentAt: sentAt,
        );

    test('ordena da mais antiga para a mais recente', () {
      final sorted = MessageMapper.sortedBySentAt(<Message>[
        at('b', DateTime(2026, 8, 9, 12)),
        at('c', DateTime(2026, 8, 9, 13)),
        at('a', DateTime(2026, 8, 9, 11)),
      ]);

      expect(sorted.map((m) => m.id), <String>['a', 'b', 'c']);
    });

    test('a mensagem recém-enviada fica por último, não no topo', () {
      // Com `orderBy('sentAt')` o Firestore devolve o documento pendente
      // (sentAt nulo) em primeiro lugar, porque nulo é o menor valor. Reordenar
      // no cliente pelo horário já resolvido evita o salto na tela.
      final pendente =
          MessageMapper.fromMap('pendente', 'c_douglas', <String, dynamic>{
        'senderId': 'uid_joao',
        'text': 'acabei de enviar',
      });
      final antiga = at('antiga', DateTime(2026, 8, 9, 11));

      final sorted = MessageMapper.sortedBySentAt(<Message>[pendente, antiga]);

      expect(sorted.map((m) => m.id), <String>['antiga', 'pendente']);
    });
  });
}

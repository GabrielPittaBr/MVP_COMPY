import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/data/mappers/conversation_mapper.dart';

void main() {
  const meuUid = 'uid_joao';

  Map<String, dynamic> doc({
    List<String>? members,
    Map<String, dynamic>? summaries,
    Object? lastMessageAt,
    Map<String, dynamic>? unreadCounts,
  }) =>
      <String, dynamic>{
        'members': members ?? <String>[meuUid, 'uid_douglas'],
        'memberSummaries': summaries ??
            <String, dynamic>{
              meuUid: <String, dynamic>{
                'id': meuUid,
                'name': 'João',
                'handle': '@joao',
                'avatarUrl': 'joao.png',
              },
              'uid_douglas': <String, dynamic>{
                'id': 'uid_douglas',
                'name': 'Douglas',
                'handle': '@douglas',
                'avatarUrl': 'douglas.png',
              },
            },
        'lastMessage': 'Bora treinar?',
        if (lastMessageAt != null) 'lastMessageAt': lastMessageAt,
        if (unreadCounts != null) 'unreadCounts': unreadCounts,
      };

  group('ConversationMapper.fromMap', () {
    test('o peer é o membro que não sou eu', () {
      final conversation = ConversationMapper.fromMap('c1', doc(), meuUid);

      expect(conversation.id, 'c1');
      expect(conversation.peer.id, 'uid_douglas');
      expect(conversation.peer.name, 'Douglas');
      expect(conversation.lastMessage, 'Bora treinar?');
    });

    test('lê o contador de não-lidas do próprio uid', () {
      final conversation = ConversationMapper.fromMap(
        'c1',
        doc(unreadCounts: <String, dynamic>{meuUid: 3, 'uid_douglas': 7}),
        meuUid,
      );

      expect(conversation.unreadCount, 3);
    });

    test('sem contador registrado, não-lidas é zero', () {
      final conversation = ConversationMapper.fromMap('c1', doc(), meuUid);

      expect(conversation.unreadCount, 0);
    });

    test('conversa sem memberSummaries não quebra a lista', () {
      final conversation = ConversationMapper.fromMap(
        'c1',
        doc(summaries: <String, dynamic>{}),
        meuUid,
      );

      expect(conversation.peer.id, 'uid_douglas');
      expect(conversation.peer.name, isNotEmpty);
    });

    test('UID de members prevalece sobre id divergente e resumos alheios', () {
      final data = doc(summaries: {
        'intruso': {'id': 'intruso', 'name': 'Outro'},
        'uid_douglas': {'id': 'id_antigo', 'name': 'Douglas'},
      });
      final conversation = ConversationMapper.fromMap('c1', data, meuUid);
      expect(conversation.peer.id, 'uid_douglas');
      expect(conversation.peer.name, 'Douglas');
      expect(conversation.peer.avatarUrl, isEmpty);
    });

    test('resumo malformado preserva UID e usa placeholder', () {
      final conversation = ConversationMapper.fromMap(
          'c1', doc(summaries: {'uid_douglas': 'invalido'}), meuUid);
      expect(conversation.peer.id, 'uid_douglas');
      expect(conversation.peer.avatarUrl, isEmpty);
    });

    test('legado sem members usa a chave do resumo como UID', () {
      final data = doc()..remove('members');
      final conversation = ConversationMapper.fromMap('c1', data, meuUid);
      expect(conversation.peer.id, 'uid_douglas');
    });

    test('sem membros nem resumos usa identidade desconhecida', () {
      final conversation = ConversationMapper.fromMap('c1', {}, meuUid);
      expect(conversation.peer, ConversationMapper.unknownPeer);
    });

    test('conversa recém-criada ainda não tem lastMessageAt do servidor', () {
      // O `serverTimestamp()` só volta preenchido na confirmação. Até lá o
      // horário é o local — a conversa acabou de acontecer, e cair na época
      // zero a mandaria para o fundo da lista.
      final before = DateTime.now();
      final conversation = ConversationMapper.fromMap('c1', doc(), meuUid);
      final after = DateTime.now();

      expect(conversation.lastMessageAt.isBefore(before), isFalse);
      expect(conversation.lastMessageAt.isAfter(after), isFalse);
    });

    test('usa o lastMessageAt gravado quando ele existe', () {
      final quando = DateTime(2026, 8, 9, 14, 30);
      final conversation = ConversationMapper.fromMap(
        'c1',
        doc(lastMessageAt: Timestamp.fromDate(quando)),
        meuUid,
      );

      expect(conversation.lastMessageAt, quando);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/data/datasources/in_memory_chat_store.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/profile/data/datasources/mock_profile.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

void main() {
  final store = InMemoryChatStore.instance;

  group('InMemoryChatStore — conversas de exemplo', () {
    test('as conversas semeadas usam o id determinístico', () {
      // Se usassem apelido ('c_douglas'), buscar Douglas na "nova conversa"
      // não acharia a conversa semeada e criaria uma segunda, vazia.
      final esperado = Conversation.idBetween(
        InMemoryChatStore.currentUserId,
        'u_douglas',
      );

      expect(
        store.conversationsSnapshot.map((c) => c.id),
        contains(esperado),
      );
    });

    test('a conversa semeada tem o histórico de mensagens', () async {
      final id = Conversation.idBetween(
        InMemoryChatStore.currentUserId,
        'u_douglas',
      );

      final messages = await store.watchMessages(id).first;
      expect(messages, isNotEmpty);
    });

    test('todo peer buscável tem id compatível com o catálogo mockado', () {
      // A busca devolve `MockProfile.searchable`; abrir conversa com um deles
      // precisa cair no mesmo id das conversas semeadas.
      final buscaveis = MockProfile.searchable.map((u) => u.id).toSet();
      expect(buscaveis, containsAll(<String>['u_douglas', 'u_hercules']));
    });
  });

  group('InMemoryChatStore.ensureConversation', () {
    test('não duplica conversa que já existe', () {
      final id = Conversation.idBetween(
        InMemoryChatStore.currentUserId,
        'u_douglas',
      );
      final antes = store.conversationsSnapshot.length;

      store.ensureConversation(
        id: id,
        peer: const UserSummary(
          id: 'u_douglas',
          name: 'Douglas',
          handle: '@douglas',
          avatarUrl: '',
        ),
      );

      expect(store.conversationsSnapshot.length, antes);
      expect(
        store.conversationsSnapshot.where((c) => c.id == id).length,
        1,
      );
    });

    test('cria a conversa quando o peer ainda não tem uma', () {
      final id = Conversation.idBetween(
        InMemoryChatStore.currentUserId,
        'u_marina',
      );
      final antes = store.conversationsSnapshot.length;

      store.ensureConversation(
        id: id,
        peer: const UserSummary(
          id: 'u_marina',
          name: 'Marina',
          handle: '@marina',
          avatarUrl: '',
        ),
      );

      expect(store.conversationsSnapshot.length, antes + 1);
      expect(store.conversationsSnapshot.first.id, id);
    });
  });
}

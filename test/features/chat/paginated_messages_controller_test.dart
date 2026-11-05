import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/domain/repositories/chat_repository.dart';
import 'package:mvp_compy/features/chat/presentation/models/chat_timeline.dart';
import 'package:mvp_compy/features/chat/presentation/pages/chat_room_page.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

const _peer =
    UserSummary(id: 'peer', name: 'Ana', handle: '@ana', avatarUrl: '');

/// Uma mensagem por hora a partir de 1/11 8h: 45 mensagens cobrem três dias,
/// e as páginas de 20 cortam o dia no meio.
Message _msg(int i, {String senderId = 'peer'}) => Message(
      id: 'm$i',
      conversationId: 'c',
      senderId: senderId,
      text: 'Mensagem $i',
      sentAt: DateTime(2026, 11, 1, 8).add(Duration(hours: i)),
    );

/// Histórico em memória com a mesma janela e o mesmo cursor (índice na
/// lista) do modo mock.
class _Chat implements ChatRepository {
  _Chat(int count)
      : history = <Message>[for (var i = 0; i < count; i++) _msg(i)];

  final List<Message> history;
  final olderCursors = <Object>[];
  bool failOlder = false;
  bool cancelled = false;
  bool autoEmit = true;
  int reads = 0;
  late final _live = StreamController<PagedResult<Message>>.broadcast(
    onListen: () {
      if (autoEmit) scheduleMicrotask(emit);
    },
    onCancel: () => cancelled = true,
  );

  void emit() {
    final start = history.length > 20 ? history.length - 20 : 0;
    _live.add(PagedResult<Message>(
      items: history.sublist(start),
      cursor: start,
      hasMore: start > 0,
    ));
  }

  void emitRaw(PagedResult<Message> page) => _live.add(page);

  void receive(Message message) {
    history.add(message);
    emit();
  }

  @override
  Stream<PagedResult<Message>> watchRecentMessages(
    String conversationId, {
    int limit = 20,
  }) {
    expect(limit, 20);
    return _live.stream;
  }

  @override
  Future<PagedResult<Message>> fetchOlderMessages(
    String conversationId, {
    required Object cursor,
    int pageSize = 20,
  }) async {
    olderCursors.add(cursor);
    if (failOlder) throw StateError('sem rede');
    final end = cursor as int;
    final start = end > pageSize ? end - pageSize : 0;
    return PagedResult<Message>(
      items: history.sublist(start, end),
      cursor: start,
      hasMore: start > 0,
    );
  }

  @override
  Stream<PagedResult<Conversation>> watchConversationsFirstPage(
    String userId, {
    int limit = 10,
  }) =>
      Stream<PagedResult<Conversation>>.value(
          PagedResult.empty<Conversation>());

  @override
  Future<void> markAsRead(String conversationId) async => reads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _provider = paginatedMessagesProvider('c');

Future<(ProviderContainer, ProviderSubscription<AsyncValue<List<Message>>>)>
    _open(_Chat chat) async {
  final container = ProviderContainer(overrides: <Override>[
    chatRepositoryProvider.overrideWithValue(chat),
  ]);
  addTearDown(container.dispose);
  final sub = container.listen(_provider, (_, __) {});
  await container.read(_provider.future);
  return (container, sub);
}

List<String> _ids(ProviderContainer c) =>
    <String>[for (final m in c.read(_provider).requireValue) m.id];

List<String> _range(int from, int to) =>
    <String>[for (var i = from; i < to; i++) 'm$i'];

void main() {
  test('a primeira página traz só as 20 mais recentes', () async {
    final (container, _) = await _open(_Chat(45));

    expect(_ids(container), _range(25, 45));
    expect(container.read(_provider.notifier).hasMore, isTrue);
  });

  test('loadMore anexa as anteriores em ordem, sem duplicar, até o fim',
      () async {
    final chat = _Chat(45);
    final (container, _) = await _open(chat);
    final controller = container.read(_provider.notifier);

    await controller.loadMore();
    expect(_ids(container), _range(5, 45));
    await controller.loadMore();
    expect(_ids(container), _range(0, 45));
    expect(controller.hasMore, isFalse);

    await controller.loadMore(); // Histórico acabou: não busca de novo.
    expect(chat.olderCursors, <Object>[25, 5]);

    // Um separador por dia, mesmo com as páginas cortando o dia no meio.
    final separators = buildChatTimeline(container.read(_provider).requireValue)
        .whereType<ChatDaySeparator>()
        .map((s) => s.day);
    expect(separators, <DateTime>[
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 3),
    ]);
  });

  test('mensagem nova entra no fim sem tirar da tela a que saiu da janela',
      () async {
    final chat = _Chat(45);
    final (container, _) = await _open(chat);
    final controller = container.read(_provider.notifier);

    chat.receive(_msg(45));
    await Future<void>.delayed(Duration.zero);
    // A janela ao vivo agora é m26..m45, mas m25 continua na tela.
    expect(_ids(container), _range(25, 46));

    // O cursor não andou com a janela: a próxima página começa antes de m25.
    await controller.loadMore();
    expect(chat.olderCursors, <Object>[25]);
    expect(_ids(container), _range(5, 46));

    chat.receive(_msg(46));
    await Future<void>.delayed(Duration.zero);
    expect(_ids(container), _range(5, 47));
  });

  test('a emissão do cache menor que a do servidor não trava a paginação',
      () async {
    final chat = _Chat(45)..autoEmit = false;
    final container = ProviderContainer(overrides: <Override>[
      chatRepositoryProvider.overrideWithValue(chat),
    ]);
    addTearDown(container.dispose);
    container.listen(_provider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    // Cache com só as 5 últimas, depois o servidor com a janela cheia.
    chat.emitRaw(PagedResult<Message>(
      items: chat.history.sublist(40),
      cursor: 40,
      hasMore: false,
    ));
    chat.emit();
    await Future<void>.delayed(Duration.zero);

    expect(_ids(container), _range(25, 45));
    expect(container.read(_provider.notifier).hasMore, isTrue);
  });

  test('falha na página antiga mantém a lista e permite repetir', () async {
    final chat = _Chat(45)..failOlder = true;
    final (container, _) = await _open(chat);
    final controller = container.read(_provider.notifier);

    await controller.loadMore();
    expect(_ids(container), _range(25, 45));
    expect(controller.loadMoreFailed, isTrue);

    chat.failOlder = false;
    await controller.loadMore();
    expect(_ids(container), _range(5, 45));
    expect(controller.loadMoreFailed, isFalse);
  });

  test('sair da sala cancela o listener das mensagens', () async {
    final chat = _Chat(3);
    final (_, sub) = await _open(chat);

    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(chat.cancelled, isTrue);
  });

  testWidgets('a sala marca como lida pela última mensagem, não pela contagem',
      (tester) async {
    final chat = _Chat(45);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        currentUserIdProvider.overrideWithValue('me'),
        chatRepositoryProvider.overrideWithValue(chat),
        publicUserSummaryProvider
            .overrideWith((ref, uid) => Stream.value(null)),
        conversationProvider('c').overrideWith(
          (ref) async => Conversation(
            id: 'c',
            peer: _peer,
            lastMessage: '',
            unreadCount: 1,
            lastMessageAt: DateTime(2026, 11, 2),
          ),
        ),
      ],
      child: const MaterialApp(home: ChatRoomPage(conversationId: 'c')),
    ));
    await tester.pumpAndSettle();
    // Ao abrir e na primeira emissão, cuja última é do outro lado.
    expect(chat.reads, 2);

    // Rolar até o topo traz a página antiga: a lista cresce sem mensagem nova.
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(chat.olderCursors, isNotEmpty);
    expect(chat.reads, 2);

    // Janela cheia: a mensagem nova não muda o tamanho da janela ao vivo.
    chat.receive(_msg(45));
    await tester.pumpAndSettle();
    expect(chat.reads, 3);

    // A minha própria mensagem não precisa zerar nada.
    chat.receive(_msg(46, senderId: 'me'));
    await tester.pumpAndSettle();
    expect(chat.reads, 3);

    // De volta ao fim da conversa, as novas estão lá.
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem 46'), findsOneWidget);
  });
}

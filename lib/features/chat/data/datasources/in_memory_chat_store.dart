import 'dart:async';

import '../../../../core/constants/app_assets.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

/// Store em memória que simula a sincronização em tempo real do Firestore
/// — mantém o tipo de stream esperado pela UI mesmo sem backend.
class InMemoryChatStore {
  InMemoryChatStore._() {
    _seed();
  }

  static final InMemoryChatStore instance = InMemoryChatStore._();

  final Map<String, UserSummary> _peers = <String, UserSummary>{};
  final List<Conversation> _conversations = <Conversation>[];
  final Map<String, List<Message>> _messages = <String, List<Message>>{};

  final StreamController<List<Conversation>> _conversationsCtl =
      StreamController<List<Conversation>>.broadcast();
  final Map<String, StreamController<List<Message>>> _messagesCtls =
      <String, StreamController<List<Message>>>{};

  /// Id do usuário "logado" mockado (usado apenas no modo sem Firebase).
  static const String currentUserId = 'u_joao';

  void _seed() {
    final douglas = UserSummary(
      id: 'u_douglas',
      name: 'Douglas',
      handle: '@douglas',
      avatarUrl: AppAssets.avatar('Douglas'),
    );
    final hercules = UserSummary(
      id: 'u_hercules',
      name: 'Hércules',
      handle: '@hercules',
      avatarUrl: AppAssets.avatar('Hércules'),
    );
    final ripelson = UserSummary(
      id: 'u_ripelson',
      name: 'Ripelson',
      handle: '@ripelson',
      avatarUrl: AppAssets.avatar('Ripelson'),
    );

    for (final p in <UserSummary>[douglas, hercules, ripelson]) {
      _peers[p.id] = p;
    }

    // Os ids seguem a mesma regra determinística do Firestore. Se fossem
    // apelidos ('c_douglas'), buscar Douglas na "nova conversa" não acharia a
    // conversa semeada e criaria uma segunda, vazia, com a mesma pessoa.
    final idDouglas = Conversation.idBetween(currentUserId, douglas.id);
    final idHercules = Conversation.idBetween(currentUserId, hercules.id);
    final idRipelson = Conversation.idBetween(currentUserId, ripelson.id);

    _conversations.addAll(<Conversation>[
      Conversation(
        id: idDouglas,
        peer: douglas,
        lastMessage: 'Encaminhou um local...',
        unreadCount: 2,
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Conversation(
        id: idHercules,
        peer: hercules,
        lastMessage: 'Encaminhou um local...',
        unreadCount: 2,
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Conversation(
        id: idRipelson,
        peer: ripelson,
        lastMessage: 'Encaminhou um local...',
        unreadCount: 2,
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);

    _messages[idDouglas] = <Message>[
      Message(
        id: 'm1',
        conversationId: idDouglas,
        senderId: douglas.id,
        text: 'Iae mano! Bora treinar nesse campo interessante aqui no centro?',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      ),
      Message(
        id: 'm2',
        conversationId: idDouglas,
        senderId: currentUserId,
        text: 'Bora mano! Em qual horário consegue marcar pra nós? Já vou chamar os guri!',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Message(
        id: 'm3',
        conversationId: idDouglas,
        senderId: douglas.id,
        text: '👍',
        sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
      ),
    ];
    _messages[idHercules] = <Message>[];
    _messages[idRipelson] = <Message>[];

    _conversationsCtl.add(List<Conversation>.unmodifiable(_conversations));
  }

  Stream<List<Conversation>> watchConversations() async* {
    yield List<Conversation>.unmodifiable(_conversations);
    yield* _conversationsCtl.stream;
  }

  /// Snapshot imutável da lista atual — usado pela paginação mock.
  List<Conversation> get conversationsSnapshot =>
      List<Conversation>.unmodifiable(_conversations);

  Stream<List<Message>> watchMessages(String conversationId) async* {
    final ctl = _messagesCtls.putIfAbsent(
      conversationId,
      () => StreamController<List<Message>>.broadcast(),
    );
    yield List<Message>.unmodifiable(_messages[conversationId] ?? <Message>[]);
    yield* ctl.stream;
  }

  /// Cria a conversa com [peer] se ela ainda não existir — o equivalente
  /// mockado do `createConversation` do Firestore, para o fluxo de "nova
  /// conversa" funcionar sem backend.
  void ensureConversation({required String id, required UserSummary peer}) {
    if (_conversations.any((c) => c.id == id)) return;

    _peers[peer.id] = peer;
    _conversations.insert(
      0,
      Conversation(
        id: id,
        peer: peer,
        lastMessage: '',
        unreadCount: 0,
        lastMessageAt: DateTime.now(),
      ),
    );
    _messages.putIfAbsent(id, () => <Message>[]);
    _conversationsCtl.add(List<Conversation>.unmodifiable(_conversations));
  }

  /// Zera as não-lidas da conversa — equivalente mockado do `markAsRead`.
  void markAsRead(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1 || _conversations[idx].unreadCount == 0) return;

    _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
    _conversationsCtl.add(List<Conversation>.unmodifiable(_conversations));
  }

  void sendMessage({
    required String conversationId,
    required String text,
    String? placeId,
  }) {
    final list = _messages.putIfAbsent(conversationId, () => <Message>[]);
    final newMsg = Message(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUserId,
      text: text,
      sentAt: DateTime.now(),
      placeId: placeId,
    );
    list.add(newMsg);
    _messagesCtls[conversationId]?.add(List<Message>.unmodifiable(list));

    // Atualiza preview da conversa
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(
        lastMessage: text,
        unreadCount: 0,
        lastMessageAt: newMsg.sentAt,
      );
      _conversationsCtl.add(List<Conversation>.unmodifiable(_conversations));
    }
  }
}

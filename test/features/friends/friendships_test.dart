import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/friends/data/datasources/friendships_remote_datasource.dart';
import 'package:mvp_compy/features/friends/data/datasources/in_memory_friendships.dart';
import 'package:mvp_compy/features/friends/data/repositories/friendships_repository_impl.dart';
import 'package:mvp_compy/features/friends/domain/entities/friendship.dart';
import 'package:mvp_compy/features/friends/domain/repositories/friendships_repository.dart';
import 'package:mvp_compy/features/friends/domain/usecases/manage_friendship.dart';
import 'package:mvp_compy/features/friends/presentation/providers/friends_providers.dart';

class _Remote implements FriendshipsRemoteDataSource {
  final calls = <String>[];
  @override
  Stream<List<Friendship>> watchFor(String uid) {
    calls.add('watch:$uid');
    return Stream.value([]);
  }

  @override
  Future<void> send(String uid, String peerId) async {
    calls.add('send:$uid:$peerId');
  }

  @override
  Future<void> act(
      String uid, Friendship expected, FriendshipAction action) async {
    calls.add('act:$uid:${action.name}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tracked implements FriendshipsRepository {
  _Tracked(this.store);
  final InMemoryFriendships store;
  int listens = 0;
  int cancels = 0;
  int sends = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Stream<List<Friendship>> watchFor(String uid) => Stream.multi((controller) {
        listens++;
        final sub = store
            .watchFor(uid)
            .listen(controller.addSync, onError: controller.addErrorSync);
        controller.onCancel = () {
          cancels++;
          return sub.cancel();
        };
      });
  @override
  Future<void> send(String uid, String peerId) async {
    sends++;
    await gate?.future;
    if (fail) throw StateError('offline');
    await store.send(uid, peerId);
  }

  @override
  Future<void> act(String uid, Friendship expected, FriendshipAction action) =>
      store.act(uid, expected, action);
}

void main() {
  test('trocar de conta ou sair libera o grafo anterior', () async {
    final store = InMemoryFriendships();
    addTearDown(store.dispose);
    await store.send('a', 'b');
    final repo = _Tracked(store);
    final selected = StateProvider<String?>((ref) => 'a');
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(selected)),
      friendshipsRepositoryProvider.overrideWithValue(repo),
    ]);
    final sub = container.listen(friendshipsProvider, (_, __) {});
    await container.read(friendshipsProvider.future);
    expect(sub.read().valueOrNull, hasLength(1));
    container.read(selected.notifier).state = 'c';
    await container.read(friendshipsProvider.future);
    expect(sub.read().valueOrNull, isEmpty);
    expect(repo.cancels, 1);
    container.read(selected.notifier).state = null;
    await container.read(friendshipsProvider.future);
    expect(sub.read().valueOrNull, isEmpty);
    expect(repo.cancels, 2);
    sub.close();
    container.dispose();
  });
  test('par é canônico e não colide com UIDs contendo sublinhado', () {
    expect(Friendship.pairId('a_b', 'c'), 'a_b:c');
    expect(Friendship.pairId('c', 'a_b'), 'a_b:c');
    expect(Friendship.pairId('a', 'b_c'), isNot('a_b:c'));
    for (final pair in [('a', 'a'), ('', 'b'), ('a:b', 'c'), ('a/b', 'c')]) {
      expect(() => Friendship.pairId(pair.$1, pair.$2), throwsArgumentError);
    }
  });
  test('mapper usa timestamps do Firestore, estado e identidade por UID', () {
    final now = DateTime(2026, 11, 2);
    final mapped = FriendshipMapper.fromMap({
      'members': ['a', 'b'],
      'senderId': 'b',
      'status': 'accepted',
      'requestedAt': Timestamp.fromDate(now),
      'acceptedAt': Timestamp.fromDate(now),
    });
    expect(mapped.peerOf('a'), 'b');
    expect(mapped.requestedAt, now);
    expect(mapped.status, FriendshipStatus.accepted);
    expect(() => mapped.peerOf('c'), throwsStateError);
  });
  test('repositório remoto delega sem criar relações mockadas', () async {
    final mock = InMemoryFriendships();
    addTearDown(mock.dispose);
    final remote = _Remote();
    final repository = FriendshipsRepositoryImpl(remote, mock);
    final manage = ManageFriendship(repository);
    await manage.send('a', 'b');
    await repository.watchFor('a').first;
    final pending = Friendship(
        members: const ['a', 'b'],
        senderId: 'a',
        status: FriendshipStatus.pending,
        requestedAt: DateTime(2026));
    await manage.act('b', pending, FriendshipAction.accept);
    expect(remote.calls, ['send:a:b', 'watch:a', 'act:b:accept']);
    expect(mock.relations, isEmpty);
  });
  test(
      'dois clientes mock: envio duplicado/cruzado, aceite, remoção, recusa e cancelamento',
      () async {
    final store = InMemoryFriendships();
    addTearDown(store.dispose);
    final manage = ManageFriendship(FriendshipsRepositoryImpl(null, store));
    await Future.wait(
        [manage.send('a', 'b'), manage.send('b', 'a'), manage.send('a', 'b')]);
    expect(store.relations, hasLength(1));
    final pending = store.relations.values.single;
    expect(() => manage.act('a', pending, FriendshipAction.accept),
        throwsStateError);
    expect(() => manage.act('c', pending, FriendshipAction.accept),
        throwsStateError);
    await manage.act('b', pending, FriendshipAction.accept);
    final accepted = store.relations.values.single;
    expect((await store.watchFor('a').first).single, accepted);
    expect((await store.watchFor('b').first).single, accepted);
    await manage.act('a', accepted, FriendshipAction.remove);
    await manage.act('a', accepted, FriendshipAction.remove);
    expect(store.relations, isEmpty);
    await manage.send('a', 'b');
    await manage.act(
        'b', store.relations.values.single, FriendshipAction.decline);
    expect(store.relations, isEmpty);
    await manage.send('a', 'b');
    await manage.act(
        'a', store.relations.values.single, FriendshipAction.cancel);
    expect(store.relations, isEmpty);
    expect(() => manage.send('a', 'a'), throwsArgumentError);
  });
  test('ação de snapshot antigo não remove nem aceita solicitação nova',
      () async {
    final store = InMemoryFriendships();
    addTearDown(store.dispose);
    await store.send('a', 'b');
    final previous = store.relations.values.single;
    await store.act('a', previous, FriendshipAction.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await store.send('a', 'b');
    await expectLater(
        store.act('b', previous, FriendshipAction.accept), throwsStateError);
    expect(store.relations.values.single.status, FriendshipStatus.pending);
  });
  test(
      'providers compartilham uma assinatura, liberam recursos e isolam a sessão',
      () async {
    final store = InMemoryFriendships();
    addTearDown(store.dispose);
    final repo = _Tracked(store);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('a'),
      friendshipsRepositoryProvider.overrideWithValue(repo),
    ]);
    final one = container.listen(friendshipWithProvider('b'), (_, __) {});
    final two = container.listen(friendshipWithProvider('c'), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(repo.listens, 1);
    await store.send('a', 'b');
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(one.read().valueOrNull?.senderId, 'a');
    expect(two.read().valueOrNull, isNull);
    one.close();
    two.close();
    await container.pump();
    expect(repo.cancels, 1);
    container.dispose();
  });
  test(
      'controller bloqueia envio simultâneo e permite repetir falha sem confirmar amizade',
      () async {
    final store = InMemoryFriendships();
    addTearDown(store.dispose);
    final repo = _Tracked(store)
      ..fail = true
      ..gate = Completer<void>();
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('a'),
      friendshipsRepositoryProvider.overrideWithValue(repo),
    ]);
    final sub = container.listen(friendshipControllerProvider('b'), (_, __) {});
    await container.read(friendshipControllerProvider('b').future);
    final controller =
        container.read(friendshipControllerProvider('b').notifier);
    final pending = controller.execute(FriendshipAction.send);
    expect(await controller.execute(FriendshipAction.send), isFalse);
    expect(repo.sends, 1);
    repo.gate!.complete();
    expect(await pending, isFalse);
    expect(store.relations, isEmpty);
    repo.fail = false;
    repo.gate = null;
    expect(await controller.execute(FriendshipAction.send), isTrue);
    expect(store.relations.values.single.status, FriendshipStatus.pending);
    sub.close();
    container.dispose();
  });
}

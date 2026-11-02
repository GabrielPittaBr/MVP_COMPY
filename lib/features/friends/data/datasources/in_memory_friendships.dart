import 'dart:async';
import '../../domain/entities/friendship.dart';

/// Store compartilhado entre clientes mockados; começa vazio.
class InMemoryFriendships {
  final Map<String, Friendship> relations = {};
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<List<Friendship>> watchFor(String uid) async* {
    // Inscreve antes de emitir o primeiro snapshot, para não perder mudanças.
    final updates = _changes.stream.map((_) => _for(uid));
    yield* Stream<List<Friendship>>.multi((controller) {
      final subscription =
          updates.listen(controller.addSync, onError: controller.addErrorSync);
      controller.addSync(_for(uid));
      controller.onCancel = subscription.cancel;
    });
  }

  List<Friendship> _for(String uid) => List.unmodifiable(
      relations.values.where((item) => item.members.contains(uid)));
  Future<void> send(String uid, String peerId) async {
    final id = Friendship.pairId(uid, peerId);
    if (relations.containsKey(id)) return;
    relations[id] = Friendship(
        members: List.unmodifiable([uid, peerId]..sort()),
        senderId: uid,
        status: FriendshipStatus.pending,
        requestedAt: DateTime.now());
    _changes.add(null);
  }

  Future<void> act(
      String uid, Friendship expected, FriendshipAction action) async {
    final current = relations[expected.id];
    if (current == null && action != FriendshipAction.accept) return;
    if (current != expected) throw StateError('A relação mudou');
    current!.requireAction(uid, action);
    if (action == FriendshipAction.accept) {
      relations[expected.id] = Friendship(
          members: current.members,
          senderId: current.senderId,
          status: FriendshipStatus.accepted,
          requestedAt: current.requestedAt,
          acceptedAt: DateTime.now());
    } else {
      relations.remove(expected.id);
    }
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

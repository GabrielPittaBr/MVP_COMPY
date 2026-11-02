import '../entities/friendship.dart';

abstract interface class FriendshipsRepository {
  Stream<List<Friendship>> watchFor(String uid);
  Future<void> send(String uid, String peerId);
  Future<void> act(String uid, Friendship expected, FriendshipAction action);
}

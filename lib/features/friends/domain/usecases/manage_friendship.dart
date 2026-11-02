import '../entities/friendship.dart';
import '../repositories/friendships_repository.dart';

class ManageFriendship {
  const ManageFriendship(this.repository);
  final FriendshipsRepository repository;
  Future<void> send(String uid, String peerId) {
    Friendship.pairId(uid, peerId);
    return repository.send(uid, peerId);
  }

  Future<void> act(String uid, Friendship expected, FriendshipAction action) {
    expected.requireAction(uid, action);
    return repository.act(uid, expected, action);
  }
}

class WatchFriendships {
  const WatchFriendships(this.repository);
  final FriendshipsRepository repository;
  Stream<List<Friendship>> call(String uid) => repository.watchFor(uid);
}

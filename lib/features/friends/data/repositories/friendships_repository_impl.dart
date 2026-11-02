import '../../../../core/constants/app_flags.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/repositories/friendships_repository.dart';
import '../datasources/friendships_remote_datasource.dart';
import '../datasources/in_memory_friendships.dart';

class FriendshipsRepositoryImpl implements FriendshipsRepository {
  FriendshipsRepositoryImpl(this.remote, this.mock);
  final FriendshipsRemoteDataSource? remote;
  final InMemoryFriendships mock;
  // A DI só fornece remote quando Firebase está inicializado.
  bool get _real => kUseFirebaseRepos && remote != null;
  @override
  Stream<List<Friendship>> watchFor(String uid) =>
      _real ? remote!.watchFor(uid) : mock.watchFor(uid);
  @override
  Future<void> send(String uid, String peerId) =>
      _real ? remote!.send(uid, peerId) : mock.send(uid, peerId);
  @override
  Future<void> act(String uid, Friendship expected, FriendshipAction action) =>
      _real
          ? remote!.act(uid, expected, action)
          : mock.act(uid, expected, action);
}

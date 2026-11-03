import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_flags.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../data/datasources/friendships_remote_datasource.dart';
import '../../data/datasources/in_memory_friendships.dart';
import '../../data/repositories/friendships_repository_impl.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/repositories/friendships_repository.dart';
import '../../domain/usecases/manage_friendship.dart';

final friendshipsRemoteProvider = Provider<FriendshipsRemoteDataSource?>(
    (ref) => kUseFirebaseRepos && firebaseEnabled
        ? FriendshipsRemoteDataSource(FirebaseFirestore.instance)
        : null);
final inMemoryFriendshipsProvider = Provider<InMemoryFriendships>((ref) {
  final store = InMemoryFriendships();
  ref.onDispose(store.dispose);
  return store;
});
final friendshipsRepositoryProvider = Provider<FriendshipsRepository>((ref) =>
    FriendshipsRepositoryImpl(ref.watch(friendshipsRemoteProvider),
        ref.watch(inMemoryFriendshipsProvider)));
final manageFriendshipProvider = Provider(
    (ref) => ManageFriendship(ref.watch(friendshipsRepositoryProvider)));
final watchFriendshipsProvider = Provider(
    (ref) => WatchFriendships(ref.watch(friendshipsRepositoryProvider)));

/// Uma assinatura para o grafo privado da sessão, sem listener por perfil.
final friendshipsProvider = StreamProvider.autoDispose<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(watchFriendshipsProvider)(uid);
});
final friendshipWithProvider =
    Provider.autoDispose.family<AsyncValue<Friendship?>, String>((ref, peer) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(friendshipsProvider).whenData((items) {
    for (final item in items) {
      if (item.members.contains(peer) && item.members.contains(uid)) {
        return item;
      }
    }
    return null;
  });
});

class FriendshipController
    extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  Future<void> build(String arg) async {}
  Future<bool> execute(FriendshipAction action, {Friendship? expected}) async {
    if (state.isLoading) return false;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return false;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final manage = ref.read(manageFriendshipProvider);
      if (action == FriendshipAction.send) {
        await manage.send(uid, arg);
      } else {
        if (expected == null) throw StateError('Relação indisponível');
        await manage.act(uid, expected, action);
      }
    });
    final success = !state.hasError;
    keepAlive.close();
    return success;
  }
}

final friendshipControllerProvider = AsyncNotifierProvider.autoDispose
    .family<FriendshipController, void, String>(FriendshipController.new);

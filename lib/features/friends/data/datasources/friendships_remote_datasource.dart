import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/friendship.dart';

class FriendshipMapper {
  static Friendship fromMap(Map<String, dynamic> data) => Friendship(
        members: List<String>.unmodifiable(data['members'] as List),
        senderId: data['senderId'] as String,
        status: FriendshipStatus.values.byName(data['status'] as String),
        requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      );
}

class FriendshipsRemoteDataSource {
  FriendshipsRemoteDataSource(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('friendships');

  // Só metadados do próprio usuário. Perfis são carregados pela UI visível.
  Stream<List<Friendship>> watchFor(String uid) => _collection
      .where('members', arrayContains: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => FriendshipMapper.fromMap(doc.data()))
          .toList());

  Future<void> send(String uid, String peerId) {
    final id = Friendship.pairId(uid, peerId);
    final members = [uid, peerId]..sort();
    final reference = _collection.doc(id);
    return firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return; // Inclusive solicitações cruzadas.
      transaction.set(reference, <String, dynamic>{
        'members': members,
        'senderId': uid,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> act(String uid, Friendship expected, FriendshipAction action) =>
      firestore.runTransaction((transaction) async {
        final reference = _collection.doc(expected.id);
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          if (action != FriendshipAction.accept) return;
          throw StateError('A solicitação não existe mais');
        }
        final current = FriendshipMapper.fromMap(snapshot.data()!);
        // Repetição do aceite já confirmado é inofensiva.
        if (action == FriendshipAction.accept &&
            current.status == FriendshipStatus.accepted &&
            current.requestedAt == expected.requestedAt &&
            current.senderId == expected.senderId) {
          return;
        }
        if (current != expected) throw StateError('A relação mudou');
        current.requireAction(uid, action);
        if (action == FriendshipAction.accept) {
          transaction.update(reference, <String, dynamic>{
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.delete(reference);
        }
      });
}

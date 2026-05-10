import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore real do chat. Quando a flag `kUseFirebaseRepos`
/// estiver ligada, este componente entrega streams reais via
/// `snapshots()`, atendendo o RNF02 (sincronização instantânea).
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) {
    final batch = _firestore.batch();
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, <String, Object?>{
      'senderId': senderId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(convRef, <String, Object?>{
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }
}

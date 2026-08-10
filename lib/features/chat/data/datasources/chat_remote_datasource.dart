import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore real do chat. Quando a flag `kUseFirebaseRepos`
/// estiver ligada, este componente entrega streams reais via
/// `snapshots()`, atendendo o RNF02 (sincronização instantânea).
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Página de conversas do usuário, mais recentes primeiro. Passe o
  /// último documento da página anterior em [startAfter] para buscar a
  /// próxima (paginação com `startAfterDocument`).
  ///
  /// Requer índice composto `members` (array-contains) +
  /// `lastMessageAt` (desc) — ver `firestore.indexes.json`.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchConversationsPage(
    String userId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('conversations')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Uma conversa avulsa, pelo id.
  ///
  /// A sala usa isto quando a conversa não está na página já carregada da
  /// lista — abrir por link direto, logo depois de criar, ou vindo de fora
  /// do chat. As regras recusam a leitura de conversa alheia, então a falha
  /// esperada aqui é `permission-denied`, não "documento inexistente".
  Future<DocumentSnapshot<Map<String, dynamic>>> fetchConversation(
    String conversationId,
  ) {
    return _firestore.collection('conversations').doc(conversationId).get();
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

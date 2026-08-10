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

  /// Cria `conversations/{conversationId}`.
  ///
  /// **Só chamar depois de confirmar que a conversa não existe** — quem faz
  /// isso é o repositório. Este `set` não é inofensivo sobre documento
  /// existente: quando membros e resumos chegam iguais, as regras deixam
  /// passar como update e o payload aqui zera `lastMessage` e `unreadCounts`.
  ///
  /// `memberSummaries` precisa nascer aqui: a regra de update proíbe alterá-lo
  /// depois, então não há segunda chance de preencher nome e avatar.
  Future<void> createConversation({
    required String conversationId,
    required Map<String, dynamic> memberSummaries,
  }) async {
    final members = memberSummaries.keys.toList();
    try {
      await _firestore.collection('conversations').doc(conversationId).set(
        <String, Object?>{
          'members': members,
          'memberSummaries': memberSummaries,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts': <String, Object?>{for (final uid in members) uid: 0},
        },
      );
    } on FirebaseException catch (e) {
      // Os dois lados criando ao mesmo tempo: o perdedor da corrida tenta
      // gravar membros diferentes dos que já estão lá e é recusado. O
      // documento existe, que é o que importa para seguir.
      if (e.code == 'permission-denied' || e.code == 'already-exists') return;
      rethrow;
    }
  }

  /// Grava a mensagem e o rodapé da conversa no mesmo lote.
  ///
  /// [peerId] recebe +1 em `unreadCounts`. Vai junto no lote de propósito:
  /// sem Cloud Function é o remetente quem incrementa, e separar as duas
  /// escritas deixaria o contador desalinhado da mensagem se a segunda
  /// falhasse.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String peerId,
    required String text,
    String? placeId,
  }) {
    final batch = _firestore.batch();
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, <String, Object?>{
      'senderId': senderId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
      // Só entra no documento quando existe: mensagem de texto não carrega
      // a chave, e o mapper decide o formato do balão pela presença dela.
      if (placeId != null) 'placeId': placeId,
    });
    batch.update(convRef, <String, Object?>{
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      // Notação de ponto: mexe só na chave do peer e preserva a do remetente.
      // As regras enxergam `unreadCounts` como campo alterado, que está na
      // lista permitida do update.
      'unreadCounts.$peerId': FieldValue.increment(1),
    });
    return batch.commit();
  }

  /// Zera o contador de não-lidas de [userId] na conversa.
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .update(<String, Object?>{'unreadCounts.$userId': 0});
  }
}

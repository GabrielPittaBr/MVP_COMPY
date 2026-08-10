import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/message.dart';

/// Converte `conversations/{id}/messages/{id}` para [Message].
///
/// Fica na camada de dados, e não como `Message.fromMap`, para manter
/// `domain/` livre de Firestore — mesma divisão que `Conversation` já segue.
///
/// Formato esperado do documento:
/// ```
/// senderId: String
/// text: String
/// sentAt: Timestamp (nulo enquanto o servidor não confirma)
/// ```
abstract final class MessageMapper {
  static Message fromMap(
    String id,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      // `sendMessage` grava `serverTimestamp()`, que volta **nulo** no snapshot
      // local emitido antes da confirmação do servidor. Cair no horário local
      // mantém a mensagem recém-enviada visível e no fim da lista; cair na
      // época zero a jogaria para o topo do histórico até o servidor responder.
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Ordena da mais antiga para a mais recente.
  ///
  /// O `orderBy('sentAt')` da consulta não basta: o documento ainda pendente
  /// tem `sentAt` nulo, e nulo é o menor valor na ordenação do Firestore — a
  /// mensagem que o usuário acabou de enviar chegaria em primeiro lugar e
  /// pularia para o fim assim que o servidor confirmasse.
  static List<Message> sortedBySentAt(List<Message> messages) {
    return <Message>[...messages]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }
}

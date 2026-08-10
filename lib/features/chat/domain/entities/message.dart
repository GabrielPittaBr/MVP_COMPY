import 'package:equatable/equatable.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.placeId,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime sentAt;

  /// Corpo da mensagem. Numa mensagem de local, serve de resumo para o
  /// preview da lista de conversas, onde não cabe desenhar o card.
  final String text;

  /// Id do local encaminhado, quando a mensagem é um local compartilhado.
  ///
  /// Guardar o id em vez de despejar nome e endereço no texto é o que
  /// permite tocar no card e voltar ao local no mapa.
  final String? placeId;

  /// Mensagem de local compartilhado, e não texto comum.
  bool get isPlace => placeId != null && placeId!.isNotEmpty;

  @override
  List<Object?> get props =>
      <Object?>[id, conversationId, senderId, text, sentAt, placeId];
}

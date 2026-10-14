import 'package:equatable/equatable.dart';

import '../../../../shared/models/sport.dart';

/// Dados mínimos copiados no momento em que um Local Esportivo é compartilhado.
/// Eles mantêm a mensagem legível mesmo se o documento atual deixar de estar
/// disponível; mensagens antigas podem não ter esse snapshot.
class PlaceMessageSnapshot extends Equatable {
  const PlaceMessageSnapshot({
    required this.name,
    required this.imageUrl,
    required this.primarySport,
  });

  final String name;
  final String imageUrl;
  final Sport primarySport;

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'imageUrl': imageUrl,
        'primarySport': primarySport.storageName,
      };

  static PlaceMessageSnapshot? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    const fields = <String>{'name', 'imageUrl', 'primarySport'};
    if (map.keys.toSet().difference(fields).isNotEmpty ||
        !map.keys.toSet().containsAll(fields)) {
      return null;
    }
    final name = map['name'];
    final imageUrl = map['imageUrl'];
    final sport = Sport.tryParse(map['primarySport']);
    final uri = imageUrl is String ? Uri.tryParse(imageUrl) : null;
    if (name is! String ||
        name.trim().isEmpty ||
        imageUrl is! String ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        sport == null) {
      return null;
    }
    return PlaceMessageSnapshot(
      name: name.trim(),
      imageUrl: imageUrl,
      primarySport: sport,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, imageUrl, primarySport];
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.placeId,
    this.placeSnapshot,
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

  /// Snapshot presente nas novas mensagens; ausente em mensagens legadas.
  final PlaceMessageSnapshot? placeSnapshot;

  /// Mensagem de local compartilhado, e não texto comum.
  bool get isPlace => placeId != null && placeId!.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
        id,
        conversationId,
        senderId,
        text,
        sentAt,
        placeId,
        placeSnapshot
      ];
}

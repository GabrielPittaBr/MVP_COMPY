import 'package:equatable/equatable.dart';

enum FriendshipStatus { pending, accepted }

enum FriendshipAction { send, accept, decline, cancel, remove }

/// Uma única relação por par de UIDs. Não contém dados de apresentação.
class Friendship extends Equatable {
  const Friendship(
      {required this.members,
      required this.senderId,
      required this.status,
      required this.requestedAt,
      this.acceptedAt});
  final List<String> members;
  final String senderId;
  final FriendshipStatus status;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  String get id => pairId(members[0], members[1]);
  String peerOf(String uid) {
    if (!members.contains(uid)) throw StateError('Usuário fora da relação');
    return members.firstWhere((id) => id != uid);
  }

  static String pairId(String a, String b) {
    final valid = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');
    if (a == b || !valid.hasMatch(a) || !valid.hasMatch(b)) {
      throw ArgumentError('A amizade exige dois UIDs válidos e diferentes');
    }
    final ordered = [a, b]..sort();
    return ordered.join(':');
  }

  void requireAction(String actor, FriendshipAction action) {
    if (!members.contains(actor)) throw StateError('Usuário fora da relação');
    final allowed = switch (action) {
      FriendshipAction.send => false,
      FriendshipAction.accept ||
      FriendshipAction.decline =>
        status == FriendshipStatus.pending && senderId != actor,
      FriendshipAction.cancel =>
        status == FriendshipStatus.pending && senderId == actor,
      FriendshipAction.remove => status == FriendshipStatus.accepted,
    };
    if (!allowed) {
      throw StateError('A relação mudou. Atualize e tente novamente.');
    }
  }

  @override
  List<Object?> get props =>
      [members, senderId, status, requestedAt, acceptedAt];
}

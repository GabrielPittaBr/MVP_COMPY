import 'package:equatable/equatable.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;

  @override
  List<Object?> get props => <Object?>[id, conversationId, senderId, text, sentAt];
}

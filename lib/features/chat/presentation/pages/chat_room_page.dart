import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sala de chat privada — implementada por completo no commit 8.
class ChatRoomPage extends ConsumerWidget {
  const ChatRoomPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Conversa $conversationId')),
      body: const Center(child: Text('Mensagens — em construção')),
    );
  }
}

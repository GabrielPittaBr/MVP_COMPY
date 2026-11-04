import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/models/user_summary.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import 'providers/chat_providers.dart';

/// Abre (ou cria) a conversa com [peer] e empilha a sala por cima da tela
/// atual, para o voltar retornar a ela. Falha vira aviso, nunca exceção.
///
/// A trava contra toque duplo fica com quem chama, que é quem desenha o
/// botão desabilitado.
Future<void> pushConversationWith(
    BuildContext context, WidgetRef ref, UserSummary peer) async {
  try {
    final me = await ref.read(currentUserSummaryProvider.future);
    if (me.id == peer.id) return;
    final conversationId =
        await ref.read(openConversationProvider).call(me: me, peer: peer);
    ref.invalidate(paginatedConversationsProvider);
    ref.invalidate(conversationProvider(conversationId));
    if (!context.mounted) return;
    // Sem await: o push só completa quando a sala fecha, e a trava de quem
    // chama ficaria presa até lá.
    context.push<void>('${AppRoutes.chat}/$conversationId');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.chatOpenConversationError)),
    );
  }
}

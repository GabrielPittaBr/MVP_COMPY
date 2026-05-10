import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chat_providers.dart';
import '../widgets/conversation_tile.dart';

/// Tela "5 Chat" — lista de conversas.
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chatTitle)),
      body: conversationsAsync.when(
        data: (conversations) => Column(
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, i) {
                  final c = conversations[i];
                  return ConversationTile(
                    conversation: c,
                    onTap: () => context.go('${AppRoutes.chat}/${c.id}'),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                AppStrings.chatFindMore,
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

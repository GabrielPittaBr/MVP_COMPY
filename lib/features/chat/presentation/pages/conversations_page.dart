import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chat_providers.dart';
import '../widgets/conversation_tile.dart';

/// Tela "5 Chat" — lista paginada de conversas (blocos de 10) com
/// scroll infinito.
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(paginatedConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chatTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.chatNew),
        tooltip: AppStrings.chatNewConversation,
        child: const Icon(Icons.chat_bubble_outline),
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          final hasMore =
              ref.read(paginatedConversationsProvider.notifier).hasMore;

          if (conversations.isEmpty && !hasMore) {
            return const Center(
              child: Text(
                'Nenhuma conversa ainda.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(paginatedConversationsProvider.future),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Próxima página quando faltam ~200px para o fim.
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  ref
                      .read(paginatedConversationsProvider.notifier)
                      .loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                // +1 para o footer de "carregando mais".
                itemCount: conversations.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (context, i) {
                  if (i == conversations.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final c = conversations[i];
                  return ConversationTile(
                    conversation: c,
                    onTap: () => context.go('${AppRoutes.chat}/${c.id}'),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

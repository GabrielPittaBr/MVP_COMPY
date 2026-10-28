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
    final isEmpty = conversationsAsync.hasValue &&
        conversationsAsync.valueOrNull!.isEmpty &&
        !ref.read(paginatedConversationsProvider.notifier).hasMore;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.chatTitle,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
      ),
      floatingActionButton: isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.chatNew),
              tooltip: AppStrings.chatNewConversation,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_square),
              label: const Text(AppStrings.chatNewConversation),
            ),
      body: conversationsAsync.when(
        data: (conversations) {
          final hasMore =
              ref.read(paginatedConversationsProvider.notifier).hasMore;

          if (conversations.isEmpty && !hasMore) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(paginatedConversationsProvider.future),
              child: const _EmptyConversations(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(paginatedConversationsProvider.future),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Próxima página quando faltam ~200px para o fim.
                if (!ref
                        .read(paginatedConversationsProvider.notifier)
                        .loadMoreFailed &&
                    notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  ref.read(paginatedConversationsProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                // +1 para o footer de "carregando mais".
                itemCount: conversations.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 88, endIndent: 20),
                itemBuilder: (context, i) {
                  if (i == conversations.length) {
                    if (ref
                        .read(paginatedConversationsProvider.notifier)
                        .loadMoreFailed) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: <Widget>[
                            const Text(AppStrings.chatLoadMoreError),
                            TextButton(
                              onPressed: () => ref
                                  .read(paginatedConversationsProvider.notifier)
                                  .loadMore(),
                              child: const Text(AppStrings.commonRetry),
                            ),
                          ],
                        ),
                      );
                    }
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
        error: (_, __) => _ConversationsError(
          onRetry: () => ref.invalidate(paginatedConversationsProvider),
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _EmptyIllustration(),
                    const SizedBox(height: 24),
                    const Text(
                      AppStrings.chatEmptyTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      AppStrings.chatEmptyHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.chatNew),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(AppStrings.chatStartConversation),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(190, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        height: 100,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 8,
              top: 2,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 31,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ConversationsError extends StatelessWidget {
  const _ConversationsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.wifi_off_rounded,
                size: 42,
                color: AppColors.onSurfaceMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.chatLoadErrorTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.chatLoadErrorHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text(AppStrings.commonRetry),
              ),
            ],
          ),
        ),
      );
}

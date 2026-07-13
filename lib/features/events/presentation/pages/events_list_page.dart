import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/widgets/event_card.dart';
import '../providers/events_providers.dart';

/// Aba "Eventos" — lista paginada (blocos de 10) com scroll infinito.
///
/// RN-05: filtra eventos com vagas restantes > 0; lotados ficam ocultos
/// (na vida real moveríamos para uma aba "encerrados").
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(paginatedEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.eventsTitle)),
      body: eventsAsync.when(
        data: (events) {
          final visible = events.where((e) => !e.isFull).toList();
          final hasMore = ref.read(paginatedEventsProvider.notifier).hasMore;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(paginatedEventsProvider.future),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Próxima página quando faltam ~200px para o fim.
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  ref.read(paginatedEventsProvider.notifier).loadMore();
                }
                return false;
              },
              child: visible.isEmpty && !hasMore
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text('Nenhum evento disponível.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      // +1 para o footer de "carregando mais".
                      itemCount: visible.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == visible.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final e = visible[i];
                        return EventCard(
                          event: e,
                          actionLabel: AppStrings.eventSeeMore,
                          onAction: () =>
                              context.go('${AppRoutes.events}/${e.id}'),
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

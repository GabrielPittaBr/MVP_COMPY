import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/widgets/event_card.dart';
import '../providers/events_providers.dart';

/// Aba "Eventos" — lista paginada (blocos de 10) com scroll infinito.
///
/// RN-05: filtra eventos com vagas restantes > 0; lotados ficam ocultos
/// (na vida real moveríamos para uma aba "encerrados").
///
/// O filtro de modalidade vem do [eventsSportFilterProvider] (setado pelas
/// categorias da Home) e é aplicado na consulta, não no cliente.
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(paginatedEventsProvider);
    final sportFilter = ref.watch(eventsSportFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.eventsTitle)),
      body: Column(
        children: <Widget>[
          if (sportFilter != null)
            _SportFilterChip(
              sport: sportFilter,
              onClear: () =>
                  ref.read(eventsSportFilterProvider.notifier).state = null,
            ),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final visible = events.where((e) => !e.isFull).toList();
                final hasMore =
                    ref.read(paginatedEventsProvider.notifier).hasMore;

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
                        ? _EmptyState(sport: sportFilter)
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            // +1 para o footer de "carregando mais".
                            itemCount: visible.length + (hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              if (i == visible.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
          ),
        ],
      ),
    );
  }
}

/// Chip do filtro ativo — sem ele o usuário vê uma lista curta sem
/// entender o motivo.
class _SportFilterChip extends StatelessWidget {
  const _SportFilterChip({required this.sport, required this.onClear});

  final Sport sport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: InputChip(
          avatar: Icon(sport.icon, size: 18, color: sport.color),
          label: Text(sport.label),
          onDeleted: onClear,
          deleteIcon: const Icon(Icons.close, size: 18),
          tooltip: AppStrings.eventsClearFilter,
          backgroundColor: AppColors.surfaceMuted,
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }
}

/// Estado vazio — específico por modalidade quando há filtro, com atalho
/// para criar o primeiro evento.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sport});

  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(
            children: <Widget>[
              Text(
                sport == null
                    ? AppStrings.eventsEmpty
                    : AppStrings.eventsEmptyForSport(sport!.label),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.create),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(AppStrings.eventsCreateCta),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

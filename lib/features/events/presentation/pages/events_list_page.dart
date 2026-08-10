import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../domain/entities/events_filter.dart';
import '../providers/events_providers.dart';
import '../widgets/events_filter_sheet.dart';

/// Aba "Eventos" — lista paginada (blocos de 10) com scroll infinito.
///
/// RN-05: filtra eventos com vagas restantes > 0; lotados ficam ocultos
/// (na vida real moveríamos para uma aba "encerrados").
///
/// Os critérios vêm do [eventsFilterProvider] (escritos pelas categorias
/// da Home ou pela folha de filtros) e entram na consulta, não no cliente.
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(paginatedEventsProvider);
    final filter = ref.watch(eventsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.eventsTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => showEventsFilterSheet(context),
            icon: Icon(
              filter.isEmpty ? Icons.tune : Icons.filter_alt,
              color: filter.isEmpty ? null : AppColors.primary,
            ),
            tooltip: AppStrings.eventsFilters,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (filter.isNotEmpty) _ActiveFilterChips(filter: filter),
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
                        ? _EmptyState(filter: filter)
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

/// Um chip por critério ativo — sem esse retorno visual o usuário vê uma
/// lista curta sem entender o motivo. O "x" limpa só aquele critério.
class _ActiveFilterChips extends ConsumerWidget {
  const _ActiveFilterChips({required this.filter});

  final EventsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(EventsFilter next) =>
        ref.read(eventsFilterProvider.notifier).state = next;

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: <Widget>[
          if (filter.sport != null)
            _FilterChip(
              icon: filter.sport!.icon,
              iconColor: filter.sport!.color,
              label: filter.sport!.label,
              onClear: () => update(filter.withSport(null)),
            ),
          if (filter.skillLevel != null)
            _FilterChip(
              icon: Icons.signal_cellular_alt,
              label: filter.skillLevel!.label,
              onClear: () => update(filter.withSkillLevel(null)),
            ),
          if (filter.day != null)
            _FilterChip(
              icon: Icons.calendar_today_outlined,
              label: DateFormat('dd/MM/yyyy').format(filter.day!),
              onClear: () => update(filter.withDay(null)),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onClear,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        avatar: Icon(icon, size: 18, color: iconColor ?? AppColors.onSurfaceMuted),
        label: Text(label),
        onDeleted: onClear,
        deleteIcon: const Icon(Icons.close, size: 18),
        tooltip: AppStrings.eventsClearFilter,
        backgroundColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.outline),
      ),
    );
  }
}

/// Estado vazio — específico por modalidade quando esse é o critério, com
/// atalho para criar o primeiro evento.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final EventsFilter filter;

  String get _message {
    if (filter.isEmpty) return AppStrings.eventsEmpty;
    if (filter.sport != null && filter.skillLevel == null &&
        filter.day == null) {
      return AppStrings.eventsEmptyForSport(filter.sport!.label);
    }
    return AppStrings.eventsEmptyFiltered;
  }

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
                _message,
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

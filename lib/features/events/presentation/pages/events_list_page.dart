import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/widgets/event_card.dart';
import '../providers/events_providers.dart';

/// Aba "Eventos" — lista todos os eventos disponíveis.
///
/// RN-05: filtra eventos com vagas restantes > 0; lotados ficam ocultos
/// (na vida real moveríamos para uma aba "encerrados").
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(allEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.eventsTitle)),
      body: eventsAsync.when(
        data: (events) {
          final visible = events.where((e) => !e.isFull).toList();
          if (visible.isEmpty) {
            return const Center(child: Text('Nenhum evento disponível.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = visible[i];
              return EventCard(
                event: e,
                actionLabel: AppStrings.eventSeeMore,
                onAction: () => context.go('${AppRoutes.events}/${e.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

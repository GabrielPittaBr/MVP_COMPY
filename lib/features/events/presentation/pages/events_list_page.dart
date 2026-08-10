import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/event_card.dart';
import '../../domain/entities/events_filter.dart';
import '../providers/events_providers.dart';
import '../widgets/events_filter_sheet.dart';

/// Aba "Eventos" — três seções ("Criados por mim", "Participando" e
/// "Todos os eventos"), sendo a última paginada com scroll infinito.
///
/// Um mesmo evento aparece em mais de uma seção de propósito: quem cria
/// também participa, e ver o próprio evento nos dois lugares é o esperado.
///
/// Os critérios vêm do [eventsFilterProvider] (escritos pelas categorias
/// da Home ou pela folha de filtros) e valem para as três seções.
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Expanded(child: _Sections(filter: filter)),
        ],
      ),
    );
  }
}

/// As três seções dentro de um scroll só.
///
/// Um scroll compartilhado, e não três listas aninhadas, porque a
/// paginação de "Todos os eventos" é disparada ao chegar perto do fim do
/// scroll — listas aninhadas exigiriam altura fixa por seção. O
/// [NotificationListener] continua funcionando porque as duas primeiras
/// seções vêm inteiras: o fim do scroll é sempre o fim da lista paginada.
class _Sections extends ConsumerWidget {
  const _Sections({required this.filter});

  final EventsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(paginatedEventsProvider);
    final mineAsync = ref.watch(myEventsProvider);
    final joinedAsync = ref.watch(joinedEventsProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (events) {
        // RN-05 esconde os lotados da descoberta — só dela. Nas seções
        // pessoais o evento que lotou continua sendo meu, e sumir com ele
        // seria mentir para quem acabou de criá-lo.
        final all = events.where((e) => !e.isFull).toList();
        final hasMore = ref.read(paginatedEventsProvider.notifier).hasMore;

        final slivers = <Widget>[];

        // Só entra a seção que tem o que mostrar — é assim que o cabeçalho
        // some junto com ela (D3). A divisória fica de fora da primeira
        // seção visível: não há nada acima para separar.
        void addSection(String title, List<Widget> content) {
          if (content.isEmpty) return;
          slivers.add(
            SliverToBoxAdapter(
              child: _SectionHeader(title: title, isFirst: slivers.isEmpty),
            ),
          );
          slivers.addAll(content);
        }

        addSection(AppStrings.eventsSectionMine, _sectionContent(mineAsync));
        addSection(AppStrings.eventsSectionJoined, _sectionContent(joinedAsync));

        final allContent = <Widget>[
          if (all.isNotEmpty) _eventsSliver(all),
          if (hasMore) const SliverToBoxAdapter(child: _LoadingFooter()),
        ];
        if (slivers.isEmpty) {
          // Para quem ainda não criou nem entrou em nada, um título
          // "Todos os eventos" sozinho no topo só ocuparia espaço: a aba
          // segue sendo a lista simples de antes.
          slivers.addAll(allContent);
        } else {
          addSection(AppStrings.eventsSectionAll, allContent);
        }

        return RefreshIndicator(
          onRefresh: () async {
            invalidateEventLists(ref);
            await ref.read(paginatedEventsProvider.future);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Próxima página quando faltam ~200px para o fim.
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                ref.read(paginatedEventsProvider.notifier).loadMore();
              }
              return false;
            },
            // Nenhuma seção sobreviveu: nem a lista principal tem itens ou
            // páginas pendentes.
            child: slivers.isEmpty
                ? _EmptyState(filter: filter)
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: slivers,
                  ),
          ),
        );
      },
    );
  }

  /// Conteúdo de uma seção pessoal. Enquanto carrega devolve nada: a seção
  /// aparece quando chega, em vez de reservar espaço com um spinner e
  /// empurrar a lista principal para baixo depois.
  List<Widget> _sectionContent(AsyncValue<List<Event>> async) {
    return async.when(
      loading: () => const <Widget>[],
      // Falhar em silêncio esconderia justamente o erro mais provável
      // aqui: o índice composto da consulta ainda não publicado.
      error: (_, __) => const <Widget>[
        SliverToBoxAdapter(
          child: _SectionMessage(AppStrings.eventsSectionError),
        ),
      ],
      data: (events) =>
          events.isEmpty ? const <Widget>[] : <Widget>[_eventsSliver(events)],
    );
  }

  Widget _eventsSliver(List<Event> events) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      sliver: SliverList.separated(
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = events[i];
          return EventCard(
            event: e,
            actionLabel: AppStrings.eventSeeMore,
            // "Ver mais" continua valendo num evento lotado — ver
            // [EventCard.disableWhenFull].
            disableWhenFull: false,
            onAction: () => context.go('${AppRoutes.events}/${e.id}'),
          );
        },
      ),
    );
  }
}

/// Divisória com título que separa as seções (D3).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isFirst});

  final String title;

  /// Primeira seção visível da tela — desenha só o título, sem a linha.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isFirst ? 16 : 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isFirst) ...<Widget>[
            const Divider(height: 1, color: AppColors.outline),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recado curto no lugar dos cards de uma seção (hoje, só falha de carga).
class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
      ),
    );
  }
}

/// Rodapé de "carregando a próxima página" da lista paginada.
class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();

  @override
  Widget build(BuildContext context) {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../domain/entities/events_filter.dart';
import '../providers/events_providers.dart';

/// Seletor único de filtros da aba Eventos.
///
/// Aberto de dois lugares — o "Ver mais" das categorias da Home e o ícone
/// de filtro do AppBar da lista. Uma folha só evita ter duas telas com a
/// mesma função de "escolher esporte".
///
/// [navigateToEventsOnApply] existe porque, vindo da Home, aplicar precisa
/// levar para a aba Eventos; vindo da própria lista, não há para onde ir.
Future<void> showEventsFilterSheet(
  BuildContext context, {
  bool navigateToEventsOnApply = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _EventsFilterSheet(
      navigateToEventsOnApply: navigateToEventsOnApply,
    ),
  );
}

class _EventsFilterSheet extends ConsumerStatefulWidget {
  const _EventsFilterSheet({required this.navigateToEventsOnApply});

  final bool navigateToEventsOnApply;

  @override
  ConsumerState<_EventsFilterSheet> createState() => _EventsFilterSheetState();
}

class _EventsFilterSheetState extends ConsumerState<_EventsFilterSheet> {
  /// Rascunho local: só vira o filtro real no "Aplicar", para o usuário
  /// poder mexer sem a lista piscando a cada toque.
  late EventsFilter _draft = ref.read(eventsFilterProvider);

  /// "Todos" não entra: no filtro ele significa "qualquer nível", que é o
  /// estado de nenhum selecionado.
  static final List<SkillLevel> _selectableLevels = SkillLevel.values
      .where((l) => l != SkillLevel.todos)
      .toList(growable: false);

  void _apply() {
    ref.read(eventsFilterProvider.notifier).state = _draft;
    // O router é resolvido antes do pop: depois de fechar a folha este
    // contexto já saiu da árvore e o lookup falharia.
    final router = widget.navigateToEventsOnApply ? GoRouter.of(context) : null;
    Navigator.of(context).pop();
    router?.go(AppRoutes.events);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _draft.day ?? now,
    );
    if (picked != null) {
      setState(() => _draft = _draft.withDay(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A folha nunca passa de 85% da altura — em telas baixas o conteúdo
    // rola em vez de estourar.
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      AppStrings.eventsFilterTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  if (_draft.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _draft = const EventsFilter()),
                      child: const Text(AppStrings.eventsFilterClearAll),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: <Widget>[
                  const _SectionLabel(AppStrings.eventsFilterSport),
                  const SizedBox(height: 8),
                  _SportGrid(
                    selected: _draft.sport,
                    // Tocar no esporte já marcado desmarca — é como o
                    // usuário volta para "todas as modalidades".
                    onSelected: (sport) => setState(
                      () => _draft = _draft
                          .withSport(sport == _draft.sport ? null : sport),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel(AppStrings.eventsFilterSkillLevel),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final level in _selectableLevels)
                        ChoiceChip(
                          label: Text(level.label),
                          selected: _draft.skillLevel == level,
                          onSelected: (isSelected) => setState(
                            () => _draft = _draft
                                .withSkillLevel(isSelected ? level : null),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    AppStrings.eventsFilterSkillLevelHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel(AppStrings.eventsFilterDay),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDay,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 18),
                          label: Text(
                            _draft.day == null
                                ? AppStrings.eventsFilterAnyDay
                                : DateFormat('dd/MM/yyyy').format(_draft.day!),
                          ),
                        ),
                      ),
                      if (_draft.day != null)
                        IconButton(
                          onPressed: () =>
                              setState(() => _draft = _draft.withDay(null)),
                          icon: const Icon(Icons.close),
                          tooltip: AppStrings.eventsClearFilter,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text(AppStrings.eventsFilterApply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}

/// Grade com todas as modalidades do enum — é por aqui que os 8 esportes
/// ficam alcançáveis, e não só os 3 do carrossel da Home.
class _SportGrid extends StatelessWidget {
  const _SportGrid({required this.selected, required this.onSelected});

  final Sport? selected;
  final ValueChanged<Sport> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: <Widget>[
        for (final sport in Sport.values)
          _SportTile(
            sport: sport,
            isSelected: sport == selected,
            onTap: () => onSelected(sport),
          ),
      ],
    );
  }
}

class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  final Sport sport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? sport.color.withValues(alpha: 0.18)
                  : AppColors.surfaceMuted,
              border: Border.all(
                color: isSelected ? sport.color : AppColors.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              sport.icon,
              color: isSelected ? sport.color : AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sport.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

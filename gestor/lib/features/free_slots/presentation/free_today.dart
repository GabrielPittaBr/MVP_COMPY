import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_fields.dart';
import '../../agenda/domain/agenda.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../agenda/presentation/slot_sheet.dart';
import '../../venue/presentation/venue_controller.dart';
import 'publish_form.dart';

typedef FreeGroup = ({
  int hour,
  List<int> courts,
  double? price,
  bool published,
});

/// Horários vagos e publicados de um dia, agrupados por hora.
List<FreeGroup> freeGroups(AgendaState agenda, VenueState venue, int day) {
  final hours = venue.hoursOf(day);
  final first = day == 0 ? Demo.now ~/ 60 + 1 : hours.open;
  final groups = <FreeGroup>[];
  for (var h = first; h < hours.close; h++) {
    final free = <int>[];
    final published = <int>[];
    double? price;
    for (final c in venue.activeCourts) {
      final item = agenda.at(c.number, day, h * 60, h * 60 + 60);
      if (item == null) {
        free.add(c.number);
      } else if (item.kind == ItemKind.horarioLivre) {
        published.add(c.number);
        price = item.price;
      }
    }
    if (free.isNotEmpty) {
      groups.add((hour: h, courts: free, price: null, published: false));
    }
    if (published.isNotEmpty) {
      groups.add((hour: h, courts: published, price: price, published: true));
    }
  }
  return groups;
}

/// "Publicar os livres de hoje" num toque só, com o mesmo desconto em todos
/// (RF-P12).
Future<void> publishAllFree(
  BuildContext context,
  WidgetRef ref, {
  int day = 0,
}) async {
  final venue = ref.read(venueProvider);
  final groups = [
    for (final g in freeGroups(ref.read(agendaProvider), venue, day))
      if (!g.published) g,
  ];
  if (groups.isEmpty) {
    showDone(context, 'Não há horários livres para publicar.');
    return;
  }
  final count = groups.fold(0, (n, g) => n + g.courts.length);
  var discount = venue.discountLimit;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          count == 1
              ? 'Publicar o horário livre?'
              : 'Publicar os $count horários livres?',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eles aparecem no app COMPY ${friendlyDate(day)} e saem '
                  'sozinhos quando forem reservados ou começarem.',
                ),
                const SizedBox(height: 12),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            hhmm(g.hour * 60),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFeatures: GestorTheme.tabular,
                            ),
                          ),
                        ),
                        Text(courtsLabel(g.courts)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const FieldLabel('Desconto'),
                Choices<int>(
                  options: [
                    for (var d = 0; d <= venue.discountLimit; d += 10) d,
                  ],
                  selected: discount,
                  label: (d) => d == 0 ? 'Sem desconto' : '$d%',
                  onSelected: (d) => setState(() => discount = d),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final notifier = ref.read(agendaProvider.notifier);
  var total = 0;
  for (final g in groups) {
    final full = venue.price(day, g.hour * 60, g.hour * 60 + 60);
    total += notifier.publish(
      courts: g.courts,
      day: day,
      start: g.hour * 60,
      end: g.hour * 60 + 60,
      price: full * (100 - discount) / 100,
      fullPrice: full,
    );
  }
  showDone(
    context,
    '${total == 1 ? '1 horário publicado' : '$total horários publicados'} '
    'no COMPY.',
  );
}

/// Lista curta dos horários livres de hoje, com o atalho para publicar.
class FreeTodayCard extends ConsumerWidget {
  const FreeTodayCard({this.day = 0, super.key});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    final groups = freeGroups(ref.watch(agendaProvider), venue, day);
    final free = groups
        .where((g) => !g.published)
        .fold(0, (n, g) => n + g.courts.length);
    return SectionCard(
      title: day == 0
          ? 'Horários livres de hoje'
          : 'Horários livres ${friendlyDate(day)}',
      gap: 4,
      children: [
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todas as quadras estão ocupadas até o fim do dia.',
              style: TextStyle(color: GestorColors.onSurfaceVariant),
            ),
          ),
        for (final g in groups)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => g.published
                ? openSlot(
                    context,
                    ref,
                    court: g.courts.first,
                    day: day,
                    hour: g.hour,
                  )
                : openForm(
                    context,
                    ref,
                    PublishForm(
                      courts: g.courts.toSet(),
                      day: day,
                      start: g.hour * 60,
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      hhmm(g.hour * 60),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFeatures: GestorTheme.tabular,
                      ),
                    ),
                  ),
                  Expanded(child: Text(courtsLabel(g.courts))),
                  if (g.published)
                    StatusPill(
                      label: 'No COMPY · ${money(g.price ?? 0)}',
                      background: GestorColors.secondaryContainer,
                      foreground: GestorColors.onSecondaryContainer,
                      border: GestorColors.secondary,
                    )
                  else
                    const DashedBorder(
                      radius: 999,
                      child: StatusPill(
                        label: 'Livre',
                        background: GestorColors.surface,
                        foreground: GestorColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (free > 0) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => publishAllFree(context, ref, day: day),
            icon: const Icon(Icons.sell_outlined),
            label: Text(
              free == 1 ? 'Publicar o livre' : 'Publicar os $free livres',
            ),
          ),
        ],
      ],
    );
  }
}

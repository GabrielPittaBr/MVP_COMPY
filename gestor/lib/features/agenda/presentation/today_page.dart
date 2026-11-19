import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_controller.dart';
import '../../free_slots/presentation/free_today.dart';
import '../../free_slots/presentation/publish_form.dart';
import '../../venue/presentation/venue_controller.dart';
import '../domain/agenda.dart';
import 'agenda_controller.dart';
import 'block_form.dart';
import 'booking_form.dart';
import 'court_tile.dart';
import 'request_page.dart';
import 'slot_sheet.dart';

/// Hoje (tela 2). No lugar da grade de quadras por horas, cada quadra
/// aparece desenhada, como se o atendente olhasse o local de cima, e um
/// seletor de horário mostra como elas estão agora ou mais tarde.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  int? _hour;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final venue = ref.watch(venueProvider);
    final agenda = ref.watch(agendaProvider);
    final desktop = isDesktop(context);
    final nowHour = Demo.now ~/ 60;
    final hours = [for (var h = nowHour; h < venue.hoursOf(0).close; h++) h];
    final hour = _hour ?? nowHour;
    final requests = [
      for (final r in agenda.requests)
        if (r.day == 0) r,
    ];
    final owner = session?.role.managesVenue ?? false;

    final requestsSection = requests.isEmpty
        ? null
        : _Requests(requests: requests, desktop: desktop);
    final courts = _CourtMap(
      hours: hours,
      hour: hour,
      desktop: desktop,
      onHour: (h) => setState(() => _hour = h),
    );
    final recovered = _Recovered(
      hours: agenda.recoveredHours,
      value: owner ? agenda.recoveredValue : null,
    );

    return PageScaffold(
      title: 'Hoje',
      subtitle:
          '${longDate(0)} · ${session?.name ?? ''}, '
          '${session?.role.label ?? ''}',
      mobileTitle: venue.name,
      mobileSubtitle:
          '${shortDate(0)} · ${session?.firstName ?? ''}, '
          '${session?.role.label ?? ''}',
      bell: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () => openForm(context, ref, const BlockForm()),
          icon: const Icon(Icons.block),
          label: const Text('Bloquear'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => publishAllFree(context, ref),
          icon: const Icon(Icons.sell_outlined),
          label: const Text('Publicar horários livres'),
        ),
        FilledButton.icon(
          onPressed: () => openForm(context, ref, const BookingForm()),
          icon: const Icon(Icons.add),
          label: const Text('Nova reserva'),
        ),
      ],
      children: desktop
          ? [
              // Com o painel lateral aberto o conteúdo encolhe: abaixo de
              // 1040 px, a coluna da direita desce para baixo das quadras.
              LayoutBuilder(
                builder: (context, box) {
                  final main = [
                    if (requestsSection != null) ...[
                      requestsSection,
                      const SizedBox(height: 24),
                    ],
                    courts,
                  ];
                  const side = [FreeTodayCard(), SizedBox(height: 16)];
                  if (box.maxWidth < 1040) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...main,
                        const SizedBox(height: 24),
                        ...side,
                        recovered,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: main,
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [...side, recovered],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ]
          : [
              ?requestsSection,
              courts,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          openForm(context, ref, const BookingForm()),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova reserva'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          openForm(context, ref, const BlockForm()),
                      icon: const Icon(Icons.block),
                      label: const Text('Bloquear'),
                    ),
                  ),
                ],
              ),
              recovered,
            ],
    );
  }
}

class _Requests extends ConsumerWidget {
  const _Requests({required this.requests, required this.desktop});

  final List<AgendaItem> requests;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = [for (final r in requests) _RequestCard(item: r)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Responder agora',
          badge: StatusPill(
            label: requests.length == 1 ? '1 nova' : '${requests.length} novas',
            background: GestorColors.warningContainer,
            foreground: GestorColors.onWarningContainer,
            dot: GestorColors.warning,
          ),
        ),
        if (desktop)
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth >= 720
                  ? (box.maxWidth - 12) / 2
                  : box.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in cards) SizedBox(width: width, child: c),
                ],
              );
            },
          )
        else
          for (final (i, c) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            c,
          ],
      ],
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openRequest(context, ref, item.id),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(item.title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          StatusPill(
                            label: 'vence em ${item.expiresIn} min',
                            icon: Icons.schedule,
                            background: GestorColors.warningContainer,
                            foreground: GestorColors.onWarningContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quadra ${item.court} · ${timeSpan(item.start, item.end)}'
                        ' · ${money(item.price ?? 0)}',
                      ),
                      if (item.fromFreeSlot)
                        const Text(
                          'Veio de um horário livre publicado',
                          style: TextStyle(
                            fontSize: 12,
                            color: GestorColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => refuseRequest(context, ref, item),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => confirmRequest(context, ref, item),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// As quadras do local desenhadas, no horário escolhido.
class _CourtMap extends ConsumerWidget {
  const _CourtMap({
    required this.hours,
    required this.hour,
    required this.desktop,
    required this.onHour,
  });

  final List<int> hours;
  final int hour;
  final bool desktop;
  final ValueChanged<int> onHour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    final agenda = ref.watch(agendaProvider);
    final now = hour == Demo.now ~/ 60;
    final start = hour * 60;
    final items = {
      for (final c in venue.courts)
        c.number: agenda.at(c.number, 0, start, start + 60),
    };
    final free = [
      for (final c in venue.activeCourts)
        if (items[c.number] == null) c.number,
    ];
    final tiles = [
      for (final c in venue.courts)
        CourtTile(
          court: c,
          item: items[c.number],
          onTap: () =>
              openSlot(context, ref, court: c.number, day: 0, hour: hour),
        ),
    ];
    final when = now ? 'Agora' : 'Às ${hour}h';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Quadras',
          trailing: TextButton(
            onPressed: () => context.go('/agenda'),
            child: const Text('Ver agenda do dia'),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final h in hours) ...[
                _HourChip(
                  label: h == Demo.now ~/ 60
                      ? 'Agora · ${hhmm(Demo.now)}'
                      : '${h}h',
                  selected: h == hour,
                  onTap: () => onHour(h),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          free.isEmpty
              ? '$when, todas as quadras estão ocupadas.'
              : '$when, ${free.length == 1 ? '1 quadra livre' : '${free.length} quadras livres'}. '
                    'Toque numa quadra para ver o que dá para fazer.',
          style: const TextStyle(color: GestorColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        // Quadras em pé, lado a lado, quando cabem; senão, deitadas em uma ou
        // duas colunas, como no celular.
        LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final standing =
                (box.maxWidth - gap * (tiles.length - 1)) / tiles.length;
            if (desktop && standing >= 140) {
              return SizedBox(
                height: 300,
                child: Row(
                  children: [
                    for (final (i, t) in tiles.indexed) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(child: t),
                    ],
                  ],
                ),
              );
            }
            final columns = box.maxWidth >= 640 ? 2 : 1;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 10,
              children: [
                for (final t in tiles)
                  SizedBox(width: width, height: 112, child: t),
              ],
            );
          },
        ),
        if (free.isNotEmpty && !now) ...[
          const SizedBox(height: 12),
          _PublishHint(free: free, hour: hour),
        ],
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? GestorColors.primary : GestorColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? GestorColors.primary : GestorColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: GestorTheme.tabular,
              color: selected ? Colors.white : GestorColors.onSurface,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Atalho do horário escolhido: as quadras vazias vão para o app.
class _PublishHint extends ConsumerWidget {
  const _PublishHint({required this.free, required this.hour});

  final List<int> free;
  final int hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    decoration: BoxDecoration(
      color: GestorColors.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.sell_outlined, color: GestorColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${courtsLabel(free)} ${free.length == 1 ? 'livre' : 'livres'} '
            'às ${hour}h. Que tal oferecer no COMPY?',
            style: const TextStyle(
              color: GestorColors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: GestorColors.secondary,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => openForm(
            context,
            ref,
            PublishForm(courts: free.toSet(), start: hour * 60),
          ),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );
}

/// Contador de horas recuperadas pelo COMPY (RF-P45). O valor em reais só
/// aparece para quem vê os resultados.
class _Recovered extends StatelessWidget {
  const _Recovered({required this.hours, required this.value});

  final int hours;
  final double? value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: GestorColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, color: GestorColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$hours h',
                        style: const TextStyle(
                          fontFamily: GestorTheme.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                      const TextSpan(
                        text: '  recuperadas pelo COMPY em novembro',
                      ),
                    ],
                  ),
                ),
                if (value != null)
                  Text(
                    '${money(value!)} em reservas que vieram do app',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

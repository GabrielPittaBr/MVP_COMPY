import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../venue/domain/venue.dart';
import '../../venue/presentation/venue_controller.dart';
import '../domain/agenda.dart';
import 'agenda_controller.dart';
import 'booking_form.dart';
import 'court_tile.dart';
import 'slot_sheet.dart';

/// Agenda (RF-P20): o dia com as quadras em colunas e a semana. Horário
/// livre fica em branco, sem texto, e o que dura mais de uma hora vira um
/// bloco só, para a agenda não parecer uma planilha.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  var _day = 0;
  var _week = false;
  var _court = 1;

  void _go(int day) => setState(() {
    _day = day.clamp(Demo.firstDay, Demo.lastDay);
    _week = false;
  });

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    final desktop = isDesktop(context);
    return PageScaffold(
      title: 'Agenda',
      subtitle: '${venue.name} · ${venue.courts.length} quadras',
      mobileSubtitle: _week
          ? 'Semana de ${shortDate(_weekStart(_day))}'
          : _dayLabel(_day),
      bell: true,
      actions: [
        FilledButton.icon(
          onPressed: () =>
              openForm(context, ref, BookingForm(day: _day < 0 ? 0 : _day)),
          icon: const Icon(Icons.add),
          label: const Text('Nova reserva'),
        ),
      ],
      gap: 14,
      children: [
        _Toolbar(
          day: _day,
          week: _week,
          onDay: _go,
          onWeek: (w) => setState(() => _week = w),
        ),
        if (!_week) const _Legend(),
        if (_week)
          _WeekGrid(start: _weekStart(_day), onDay: _go)
        else if (desktop)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              child: _DayGrid(day: _day, courts: venue.courts),
            ),
          )
        else ...[
          CourtPickerRow(
            courts: venue.courts,
            selected: _court,
            onSelected: (c) => setState(() => _court = c),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: _DayGrid(
                day: _day,
                courts: [venue.court(_court)],
                showHeader: false,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Segunda-feira da semana do dia.
int _weekStart(int day) => day - (Demo.date(day).weekday - 1);

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.day,
    required this.week,
    required this.onDay,
    required this.onWeek,
  });

  final int day;
  final bool week;
  final ValueChanged<int> onDay;
  final ValueChanged<bool> onWeek;

  @override
  Widget build(BuildContext context) {
    final step = week ? 7 : 1;
    final label = week
        ? 'Semana de ${shortDate(_weekStart(day))}'
        : _dayLabel(day);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: GestorColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GestorColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: week ? 'Semana anterior' : 'Dia anterior',
                onPressed: day - step >= Demo.firstDay
                    ? () => week ? onDay(day - 7) : onDay(day - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: week ? 'Próxima semana' : 'Próximo dia',
                onPressed: day + step <= Demo.lastDay
                    ? () => onDay(day + step)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (day != 0 || week)
          OutlinedButton(onPressed: () => onDay(0), child: const Text('Hoje')),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Dia')),
            ButtonSegment(value: true, label: Text('Semana')),
          ],
          selected: {week},
          onSelectionChanged: (s) => onWeek(s.first),
        ),
      ],
    );
  }
}

/// "Hoje, qui., 19/11" ou só "sáb., 21/11".
String _dayLabel(int day) {
  final friendly = friendlyDate(day);
  if (friendly == shortDate(day)) return friendly;
  return '${friendly[0].toUpperCase()}${friendly.substring(1)}, ${shortDate(day)}';
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final looks = [
      SlotLook.of(null),
      SlotLook.of(_fake(ItemKind.reserva)),
      SlotLook.of(_fake(ItemKind.solicitacao)),
      SlotLook.of(_fake(ItemKind.horarioLivre)),
      SlotLook.of(_fake(ItemKind.ocupado)),
      SlotLook.of(_fake(ItemKind.bloqueio)),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final look in looks)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Swatch(look: look),
              const SizedBox(width: 6),
              Text(
                look.label == 'Ocupada'
                    ? 'Ocupada no outro sistema'
                    : look.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: GestorColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

AgendaItem _fake(ItemKind kind) =>
    AgendaItem(id: '', court: 0, day: 0, start: 0, end: 0, kind: kind);

class _Swatch extends StatelessWidget {
  const _Swatch({required this.look});

  final SlotLook look;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 18,
      height: 14,
      decoration: BoxDecoration(
        color: look.background,
        borderRadius: BorderRadius.circular(4),
        border: look.border == null ? null : Border.all(color: look.border!),
      ),
      child: look.hatch
          ? const CustomPaint(painter: HatchPainter(gap: 5, width: 2))
          : null,
    );
    return look.dashed ? DashedBorder(radius: 4, width: 1, child: box) : box;
  }
}

/// No celular, uma quadra por vez: as quadrinhas no topo escolhem qual.
class CourtPickerRow extends StatelessWidget {
  const CourtPickerRow({
    required this.courts,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<Court> courts;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, c) in courts.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: MiniCourt(
            court: c,
            selected: c.number == selected,
            note: c.name,
            enabled: true,
            onTap: () => onSelected(c.number),
          ),
        ),
      ],
    ],
  );
}

const _rowHeight = 52.0;
const _axisWidth = 52.0;

class _DayGrid extends ConsumerWidget {
  const _DayGrid({
    required this.day,
    required this.courts,
    this.showHeader = true,
  });

  final int day;
  final List<Court> courts;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    final hours = venue.hoursOf(day);
    final height = (hours.close - hours.open) * _rowHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              const SizedBox(width: _axisWidth),
              for (final c in courts)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _CourtHeader(court: c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HourLines(hours.close - hours.open),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimeAxis(open: hours.open, close: hours.close),
                  for (final c in courts)
                    Expanded(
                      child: _CourtColumn(
                        court: c,
                        day: day,
                        open: hours.open,
                        close: hours.close,
                      ),
                    ),
                ],
              ),
              if (day == 0 &&
                  Demo.now > hours.open * 60 &&
                  Demo.now < hours.close * 60)
                Positioned(
                  left: _axisWidth - 6,
                  right: 0,
                  top: (Demo.now - hours.open * 60) / 60 * _rowHeight - 1,
                  child: const _NowLine(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourtHeader extends StatelessWidget {
  const _CourtHeader({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final style = court.floor.style;
    return SizedBox(
      height: 54,
      child: CourtSurface(
        style: style,
        inset: 6,
        lineAlpha: 0.6,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            court.name,
            style: TextStyle(
              fontFamily: GestorTheme.display,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: style.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.open, required this.close});

  final int open;
  final int close;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _axisWidth,
    child: Column(
      children: [
        for (var h = open; h < close; h++)
          SizedBox(
            height: _rowHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: Text(
                  hhmm(h * 60),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GestorColors.onSurfaceVariant,
                    fontFeatures: GestorTheme.tabular,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _HourLines extends CustomPainter {
  const _HourLines(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = GestorColors.outlineVariant;
    for (var i = 0; i <= count; i++) {
      final y = i * _rowHeight;
      canvas.drawLine(Offset(_axisWidth, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HourLines old) => old.count != count;
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: GestorColors.error,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Container(height: 2, color: GestorColors.error)),
      ],
    ),
  );
}

class _CourtColumn extends ConsumerWidget {
  const _CourtColumn({
    required this.court,
    required this.day,
    required this.open,
    required this.close,
  });

  final Court court;
  final int day;
  final int open;
  final int close;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final items = [
      for (final i in agenda.dayItems(day))
        if (i.court == court.number) i,
    ];
    final closed = court.status != CourtStatus.ativa;
    double top(int minutes) => (minutes - open * 60) / 60 * _rowHeight;
    return Stack(
      children: [
        for (var h = open; h < close; h++)
          if (!closed &&
              agenda.at(court.number, day, h * 60, h * 60 + 60) == null)
            Positioned(
              top: top(h * 60),
              height: _rowHeight,
              left: 0,
              right: 0,
              child: _FreeCell(
                past: day < 0 || (day == 0 && (h + 1) * 60 <= Demo.now),
                onTap: () => openSlot(
                  context,
                  ref,
                  court: court.number,
                  day: day,
                  hour: h,
                ),
              ),
            ),
        if (closed)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const ColoredBox(
                  color: GestorColors.surfaceContainer,
                  child: CustomPaint(painter: HatchPainter()),
                ),
              ),
            ),
          ),
        for (final item in items)
          Positioned(
            top: top(item.start),
            height: (item.end - item.start) / 60 * _rowHeight,
            left: 0,
            right: 0,
            child: _Block(
              item: item,
              onTap: () => openSlot(
                context,
                ref,
                court: court.number,
                day: day,
                hour: item.start ~/ 60,
              ),
            ),
          ),
      ],
    );
  }
}

class _FreeCell extends StatelessWidget {
  const _FreeCell({required this.past, required this.onTap});

  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: past
        ? const SizedBox.expand()
        : DashedBorder(
            radius: 8,
            width: 1,
            color: GestorColors.outlineVariant,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                hoverColor: GestorColors.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                child: const Center(
                  child: Icon(Icons.add, size: 18, color: GestorColors.outline),
                ),
              ),
            ),
          ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.item, required this.onTap});

  final AgendaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = SlotLook.of(item);
    final (title, detail) = switch (item.kind) {
      ItemKind.reserva => (
        item.title,
        item.noShow ? 'faltou' : item.source?.label ?? '',
      ),
      ItemKind.solicitacao => (item.title.split(' ').first, 'pedido pelo app'),
      ItemKind.ocupado => ('Ocupada', 'outro sistema'),
      ItemKind.bloqueio => ('Bloqueada', item.title),
      ItemKind.horarioLivre => ('No COMPY', money(item.price ?? 0)),
      ItemKind.eventoLocal => ('Evento', '${item.taken}/${item.spots} vagas'),
    };
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: look.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: look.border == null
              ? BorderSide.none
              : BorderSide(color: look.border!, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (look.hatch) const CustomPaint(painter: HatchPainter()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: look.foreground,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: look.foreground.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semana: quantas quadras estão livres em cada hora de cada dia.
class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({required this.start, required this.onDay});

  final int start;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    final agenda = ref.watch(agendaProvider);
    final days = [for (var d = start; d < start + 7; d++) d];
    final open = venue.hours.map((h) => h.open).reduce((a, b) => a < b ? a : b);
    final close = venue.hours
        .map((h) => h.close)
        .reduce((a, b) => a > b ? a : b);
    int free(int day, int hour) => venue.activeCourts
        .where(
          (c) => agenda.at(c.number, day, hour * 60, hour * 60 + 60) == null,
        )
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                for (final d in days)
                  Expanded(
                    child: InkWell(
                      onTap: () => onDay(d),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(
                              weekdayShort(d),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: d == 0
                                    ? GestorColors.primary
                                    : GestorColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${Demo.date(d).day}',
                              style: TextStyle(
                                fontFamily: GestorTheme.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: d == 0
                                    ? GestorColors.primary
                                    : GestorColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var h = open; h < close; h++)
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${h}h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final d in days)
                    Expanded(
                      child: _WeekCell(
                        open:
                            h >= venue.hoursOf(d).open &&
                            h < venue.hoursOf(d).close,
                        free: free(d, h),
                        past: d < 0 || (d == 0 && (h + 1) * 60 <= Demo.now),
                        onTap: () => onDay(d),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            const Text(
              'O número é quantas quadras estão livres. Toque num dia para '
              'ver a agenda dele.',
              style: TextStyle(
                fontSize: 12,
                color: GestorColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.open,
    required this.free,
    required this.past,
    required this.onTap,
  });

  final bool open;
  final int free;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (!open) {
      background = GestorColors.background;
      foreground = GestorColors.outline;
    } else if (free == 0) {
      background = GestorColors.primaryContainer;
      foreground = GestorColors.primary;
    } else {
      background = GestorColors.surface;
      foreground = GestorColors.onSurface;
    }
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: open ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: open && free > 0
                  ? Border.all(color: GestorColors.outlineVariant)
                  : null,
            ),
            child: Text(
              !open
                  ? ''
                  : free == 0
                  ? 'cheio'
                  : '$free',
              style: TextStyle(
                fontSize: free == 0 ? 11 : 14,
                fontWeight: FontWeight.w600,
                color: past ? foreground.withValues(alpha: 0.5) : foreground,
                fontFeatures: GestorTheme.tabular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

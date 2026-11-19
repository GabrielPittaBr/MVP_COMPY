import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../venue/domain/venue.dart';
import '../domain/agenda.dart';

extension CourtFloorStyle on CourtFloor {
  CourtStyle get style => switch (this) {
    CourtFloor.areia => CourtStyle.areia,
    CourtFloor.sintetico => CourtStyle.padel,
    CourtFloor.grama => CourtStyle.campo,
    CourtFloor.saibro => CourtStyle.saibro,
    CourtFloor.madeira => CourtStyle.ginasio,
    CourtFloor.cimento => CourtStyle.quadra,
  };
}

IconData sourceIcon(Source? source) => switch (source) {
  Source.whatsapp => Icons.chat_outlined,
  Source.telefone => Icons.call_outlined,
  Source.balcao => Icons.storefront_outlined,
  Source.compy => Icons.phone_iphone,
  Source.mensalista => Icons.event_repeat,
  Source.outroSistema || null => Icons.sync_alt,
};

/// Cores e textos de cada estado. São os mesmos em todos os temas, para quem
/// trabalha em mais de um local (seção 7).
class SlotLook {
  const SlotLook(
    this.label,
    this.background,
    this.foreground, {
    this.border,
    this.dashed = false,
    this.hatch = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool dashed;
  final bool hatch;

  static SlotLook of(AgendaItem? item) => switch (item?.kind) {
    null => const SlotLook(
      'Livre',
      GestorColors.surface,
      GestorColors.onSurfaceVariant,
      dashed: true,
    ),
    ItemKind.reserva when item!.noShow => const SlotLook(
      'Falta',
      GestorColors.errorContainer,
      GestorColors.onErrorContainer,
    ),
    ItemKind.reserva => const SlotLook(
      'Reservada',
      GestorColors.primaryContainer,
      GestorColors.primary,
    ),
    ItemKind.solicitacao => const SlotLook(
      'Solicitada',
      GestorColors.warningContainer,
      GestorColors.onWarningContainer,
      border: GestorColors.warning,
    ),
    ItemKind.ocupado => const SlotLook(
      'Ocupada',
      GestorColors.surfaceContainer,
      GestorColors.onSurfaceVariant,
    ),
    ItemKind.bloqueio => const SlotLook(
      'Bloqueada',
      GestorColors.surfaceContainer,
      GestorColors.onSurfaceVariant,
      hatch: true,
    ),
    ItemKind.horarioLivre => const SlotLook(
      'No COMPY',
      GestorColors.secondaryContainer,
      GestorColors.onSecondaryContainer,
      border: GestorColors.secondary,
    ),
    ItemKind.eventoLocal => const SlotLook(
      'Evento do Local',
      GestorColors.secondaryContainer,
      GestorColors.onSecondaryContainer,
      border: GestorColors.secondary,
    ),
  };
}

/// Nome e detalhe de um item, em linguagem do local (princípio 5).
(String, String) describe(AgendaItem? item) => switch (item?.kind) {
  null => ('Livre', 'Toque para reservar ou publicar'),
  ItemKind.reserva => (
    item!.title,
    '${item.noShow ? 'faltou' : item.source?.label ?? ''} · '
        '${timeSpan(item.start, item.end)}',
  ),
  ItemKind.solicitacao => (
    '${item!.title.split(' ').first} pediu',
    'pelo app · vence em ${item.expiresIn} min',
  ),
  ItemKind.ocupado => (
    'Ocupada',
    'outro sistema · ${timeSpan(item!.start, item.end)}',
  ),
  ItemKind.bloqueio => (
    item!.title,
    'bloqueada · ${timeSpan(item.start, item.end)}',
  ),
  ItemKind.horarioLivre => (
    'No COMPY',
    '${money(item!.price ?? 0)} · esperando jogador',
  ),
  ItemKind.eventoLocal => (
    'Evento do Local',
    '${item!.taken} de ${item.spots} vagas · ${item.sport}',
  ),
};

/// A quadra de verdade, vista de cima, com uma plaqueta dizendo o que
/// acontece nela no horário escolhido.
class CourtTile extends StatelessWidget {
  const CourtTile({
    required this.court,
    required this.item,
    this.onTap,
    this.caption,
    super.key,
  });

  final Court court;
  final AgendaItem? item;
  final VoidCallback? onTap;

  /// Texto da plaqueta no lugar do estado (por exemplo, "19:00 às 20:00").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final look = SlotLook.of(item);
    final (title, detail) = describe(item);
    final style = court.floor.style;
    final closed = court.status != CourtStatus.ativa;
    return Semantics(
      button: onTap != null,
      label: '${court.name}, ${look.label}, $title, $detail',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final portrait = box.maxHeight > box.maxWidth;
          final number = _CourtNumber(court: court, ink: style.ink);
          final plaque = _Plaque(
            look: closed ? _closedLook : look,
            title: closed ? court.status.label : (caption ?? title),
            detail: closed ? 'sai da agenda e do app' : detail,
          );
          return Material(
            color: style.floor,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CourtSurface(
                    style: style,
                    portrait: portrait,
                    inset: 10,
                    lineAlpha: 0.7,
                  ),
                  if (look.hatch || closed)
                    const CustomPaint(
                      painter: HatchPainter(color: Color(0x2E101C3F), gap: 12),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: portrait
                        ? Column(
                            children: [
                              Expanded(child: Center(child: number)),
                              plaque,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: Center(child: number)),
                              const SizedBox(width: 14),
                              Expanded(child: plaque),
                            ],
                          ),
                  ),
                  if (look.border != null && !closed)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: look.border!, width: 3),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const _closedLook = SlotLook(
  'Fechada',
  GestorColors.surfaceContainer,
  GestorColors.onSurfaceVariant,
);

class _CourtNumber extends StatelessWidget {
  const _CourtNumber({required this.court, required this.ink});

  final Court court;
  final Color ink;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'QUADRA',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: ink.withValues(alpha: 0.85),
        ),
      ),
      Text(
        '${court.number}',
        style: TextStyle(
          fontFamily: GestorTheme.display,
          fontWeight: FontWeight.w700,
          fontSize: 46,
          height: 1,
          color: ink,
        ),
      ),
    ],
  );
}

class _Plaque extends StatelessWidget {
  const _Plaque({
    required this.look,
    required this.title,
    required this.detail,
  });

  final SlotLook look;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x29101C3F),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LookChip(look: look),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.3,
            color: GestorColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// Etiqueta pequena do estado, com borda tracejada quando está livre.
class _LookChip extends StatelessWidget {
  const _LookChip({required this.look});

  final SlotLook look;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: look.background,
        borderRadius: BorderRadius.circular(6),
        border: look.border == null ? null : Border.all(color: look.border!),
      ),
      child: Text(
        look.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: look.foreground,
          height: 1,
        ),
      ),
    );
    return look.dashed
        ? DashedBorder(radius: 6, width: 1.2, child: chip)
        : chip;
  }
}

/// Escolha de quadra nos formulários: cada opção é uma quadrinha desenhada.
class CourtPicker extends StatelessWidget {
  const CourtPicker({
    required this.courts,
    required this.selected,
    required this.onChanged,
    this.multi = false,
    this.unavailable = const {},
    super.key,
  });

  final List<Court> courts;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool multi;

  /// Quadras que não podem ser escolhidas, com o motivo curto.
  final Map<int, String> unavailable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 8.0;
      final perRow = courts.length.clamp(1, 5);
      final width = (box.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final court in courts)
            SizedBox(
              width: width,
              child: MiniCourt(
                court: court,
                selected: selected.contains(court.number),
                note:
                    unavailable[court.number] ??
                    (selected.contains(court.number) ? 'escolhida' : 'livre'),
                enabled: !unavailable.containsKey(court.number),
                onTap: () {
                  final next = {...selected};
                  if (!multi) {
                    next
                      ..clear()
                      ..add(court.number);
                  } else if (!next.remove(court.number)) {
                    next.add(court.number);
                  }
                  onChanged(next);
                },
              ),
            ),
        ],
      );
    },
  );
}

class MiniCourt extends StatelessWidget {
  const MiniCourt({
    required this.court,
    required this.selected,
    required this.note,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final Court court;
  final bool selected;
  final String note;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = court.floor.style;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${court.name}, $note',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.5,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? GestorColors.primary
                        : GestorColors.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CourtSurface(style: style, inset: 5, lineAlpha: 0.6),
                      if (!enabled)
                        const ColoredBox(
                          color: Color(0x99F3F5F9),
                          child: CustomPaint(
                            painter: HatchPainter(
                              color: Color(0x33101C3F),
                              gap: 8,
                              width: 2,
                            ),
                          ),
                        ),
                      Center(
                        child: Text(
                          '${court.number}',
                          style: TextStyle(
                            fontFamily: GestorTheme.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            height: 1,
                            color: enabled
                                ? style.ink
                                : GestorColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: GestorColors.primary,
                            child: Icon(
                              Icons.check,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? GestorColors.primary
                    : GestorColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

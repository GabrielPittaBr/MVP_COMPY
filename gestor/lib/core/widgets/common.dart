import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/gestor_colors.dart';
import '../theme/gestor_theme.dart';

/// Iniciais do local numa plaqueta branca, enquanto não há logo (RF-P51).
class Monogram extends StatelessWidget {
  const Monogram({required this.name, this.size = 48, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2E101C3F),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Text(
      initials(name),
      style: TextStyle(
        fontFamily: GestorTheme.display,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.46,
        height: 1,
        letterSpacing: size * 0.01,
        color: GestorColors.monogram,
      ),
    ),
  );
}

/// Selo discreto "com COMPY": o local é a marca (princípio 6).
class CompyBadge extends StatelessWidget {
  const CompyBadge({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 20,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Image.asset('assets/images/compy-icon-64.png'),
      ),
      const SizedBox(width: 6),
      Text(
        'com COMPY',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}

/// Painel branco com título, como os do painel admin.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.children,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.gap = 12,
    super.key,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: gap),
          ],
          for (final (i, child) in children.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            child,
          ],
        ],
      ),
    ),
  );
}

/// Etiqueta de estado arredondada.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dot,
    this.border,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? dot;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: EdgeInsets.only(
      left: icon != null || dot != null ? 8 : 10,
      right: 10,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: border == null ? null : Border.all(color: border!, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: foreground,
            height: 1.1,
          ),
        ),
      ],
    ),
  );
}

/// Pílula de "2ª versão" para o que ainda não entra no MVP.
class LaterPill extends StatelessWidget {
  const LaterPill({super.key});

  @override
  Widget build(BuildContext context) => const StatusPill(
    label: '2ª versão',
    background: GestorColors.surfaceContainer,
    foreground: GestorColors.onSurfaceVariant,
  );
}

/// Borda tracejada, usada no que está livre ou ainda pode ser criado.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    required this.child,
    this.color = GestorColors.outline,
    this.radius = 10,
    this.width = 1.5,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashPainter(color, radius, width),
    child: child,
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color, this.radius, this.width);

  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius || old.width != width;
}

/// Listras diagonais do que está bloqueado, como uma fita de interdição.
class HatchPainter extends CustomPainter {
  const HatchPainter({
    this.color = GestorColors.outlineVariant,
    this.gap = 9,
    this.width = 3,
  });

  final Color color;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HatchPainter old) =>
      old.color != color || old.gap != gap || old.width != width;
}

/// Título de seção dentro das páginas: texto à esquerda e ação à direita.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, this.badge, super.key});

  final String text;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge!],
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}

/// Linha de rótulo e valor, como na ficha da solicitação.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {this.detail, super.key});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: GestorColors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (detail != null)
                Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Aviso cinza com ícone, para explicar regras sem pesar a tela.
class NoteBox extends StatelessWidget {
  const NoteBox(
    this.text, {
    this.icon = Icons.info_outline,
    this.background = GestorColors.surfaceContainer,
    this.foreground = GestorColors.onSurfaceVariant,
    super.key,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: foreground, height: 1.45)),
        ),
      ],
    ),
  );
}

/// Avatar com as iniciais do jogador ou do membro da equipe.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {this.size = 40, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: GestorColors.surfaceContainer,
      shape: BoxShape.circle,
    ),
    child: Text(
      initials(name),
      style: TextStyle(
        color: GestorColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: size * 0.38,
      ),
    ),
  );
}

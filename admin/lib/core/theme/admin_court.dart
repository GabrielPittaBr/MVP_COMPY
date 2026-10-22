import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'admin_theme.dart';

/// Superfície azul com as linhas de uma quadra de futsal, a marca visual do
/// painel. Usada na navegação (quadra em pé) e no login (quadra deitada).
class AdminCourtSurface extends StatelessWidget {
  const AdminCourtSurface({
    required this.child,
    this.horizontal = false,
    this.minHalfway = 0,
    super.key,
  });

  final Widget child;
  final bool horizontal;

  /// Altura mínima da linha central na quadra em pé, para o círculo central
  /// não ficar atrás dos itens de navegação em telas baixas.
  final double minHalfway;

  /// Distância entre a borda da superfície e a linha lateral da quadra.
  static const double lineInset = 16;

  @override
  Widget build(BuildContext context) => Material(
    color: AdminColors.primary,
    child: CustomPaint(
      painter: _CourtLinesPainter(
        horizontal: horizontal,
        minHalfway: minHalfway,
      ),
      child: child,
    ),
  );
}

class _CourtLinesPainter extends CustomPainter {
  const _CourtLinesPainter({
    required this.horizontal,
    required this.minHalfway,
  });

  final bool horizontal;
  final double minHalfway;

  @override
  void paint(Canvas canvas, Size size) {
    // Desenha sempre a quadra em pé; deitada é a mesma quadra girada.
    var court = size;
    if (horizontal) {
      canvas
        ..translate(0, size.height)
        ..rotate(-math.pi / 2);
      court = size.flipped;
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const inset = AdminCourtSurface.lineInset;
    final field = Rect.fromLTRB(
      inset,
      inset,
      court.width - inset,
      court.height - inset,
    );
    final center = Offset(
      field.center.dx,
      math.max(field.center.dy, minHalfway),
    );
    final circleRadius = field.width * 0.2;
    final areaRadius = field.width * 0.3;

    canvas
      ..drawRect(field, line)
      ..drawLine(
        Offset(field.left, center.dy),
        Offset(field.right, center.dy),
        line,
      )
      ..drawCircle(center, circleRadius, line)
      ..drawCircle(center, 2.5, line..style = PaintingStyle.fill);
    line.style = PaintingStyle.stroke;
    for (final (goal, sweep) in <(Offset, double)>[
      (field.topCenter, math.pi),
      (field.bottomCenter, -math.pi),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: goal, radius: areaRadius),
        0,
        sweep,
        false,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_CourtLinesPainter oldDelegate) =>
      oldDelegate.horizontal != horizontal ||
      oldDelegate.minHalfway != minHalfway;
}

/// Nome do produto em branco, para uso sobre a [AdminCourtSurface].
class AdminWordmark extends StatelessWidget {
  const AdminWordmark({this.size = 32, this.centered = false, super.key});

  final double size;
  final bool centered;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'COMPY, painel administrativo',
    container: true,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'COMPY',
            style: TextStyle(
              fontFamily: AdminTheme.displayFamily,
              fontWeight: FontWeight.w700,
              fontSize: size,
              height: 1,
              letterSpacing: size * 0.04,
              color: Colors.white,
            ),
          ),
          SizedBox(height: size * 0.12),
          Text(
            'Painel administrativo',
            style: TextStyle(
              fontSize: math.max(14, size * 0.3),
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    ),
  );
}

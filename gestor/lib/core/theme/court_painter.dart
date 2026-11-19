import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Os seis desenhos de quadra: servem ao tema do local (moldura) e às quadras
/// cadastradas, que aparecem como quadras de verdade nas telas.
enum CourtStyle {
  quadra(Color(0xFF1F3A8A), Colors.white, 0.14),
  areia(Color(0xFFE6CF9F), Color(0xFF3A2A12), 0.42),
  padel(Color(0xFF1E4E8C), Colors.white, 0.26),
  campo(Color(0xFF1E6B3A), Colors.white, 0.3),
  saibro(Color(0xFFA84B24), Colors.white, 0.34),
  ginasio(Color(0xFF8A5228), Colors.white, 0.28);

  const CourtStyle(this.floor, this.ink, this.lineAlpha);

  /// Cor do piso.
  final Color floor;

  /// Cor do texto sobre o piso (contraste AA testado).
  final Color ink;

  /// Opacidade das linhas quando a quadra é só decoração (moldura).
  final double lineAlpha;
}

/// Desenha uma quadra vista de cima. Sem [portrait], o lado comprido fica na
/// horizontal (cabeçalho, cartões); com ele, em pé (menu lateral).
class CourtPainter extends CustomPainter {
  const CourtPainter({
    required this.style,
    this.portrait = false,
    this.inset = 12,
    this.lines = true,
    this.lineAlpha,
  });

  final CourtStyle style;
  final bool portrait;
  final double inset;

  /// Sem linhas, fica só o piso (barra de navegação inferior).
  final bool lines;

  /// Opacidade das linhas. Nas quadras do local, mais forte que na moldura.
  final double? lineAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = style.floor);
    var court = size;
    canvas.save();
    if (portrait) {
      canvas
        ..translate(0, size.height)
        ..rotate(-math.pi / 2);
      court = size.flipped;
    }
    _texture(canvas, court);
    if (lines) _lines(canvas, court);
    canvas.restore();
  }

  void _texture(Canvas canvas, Size s) {
    switch (style) {
      case CourtStyle.areia:
        // Grãos de areia em três camadas, com um leve desvio para não parecer
        // grade.
        for (final (color, dx, dy, ox, oy, r) in const [
          (Color(0x8CC4A062), 7.0, 9.0, 0.0, 0.0, 1.1),
          (Color(0xF2D4B67E), 13.0, 11.0, 4.0, 5.0, 1.3),
          (Color(0xBFFAF0D7), 17.0, 19.0, 9.0, 3.0, 1.0),
        ]) {
          final points = <Offset>[];
          for (var y = oy; y < s.height; y += dy) {
            for (var x = ox; x < s.width; x += dx) {
              final h = ((x * 73856093).toInt() ^ (y * 19349663).toInt()) & 7;
              points.add(Offset(x + h * 0.4 - 1.4, y + (h >> 1) * 0.5 - 1));
            }
          }
          canvas.drawPoints(
            PointMode.points,
            points,
            Paint()
              ..color = color
              ..strokeWidth = r * 2
              ..strokeCap = StrokeCap.round,
          );
        }
      case CourtStyle.campo:
        final stripe = Paint()..color = const Color(0xFF23763F);
        for (var x = 56.0; x < s.width; x += 112) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 56, s.height), stripe);
        }
      case CourtStyle.ginasio:
        final plank = Paint()..color = const Color(0xFF7F4B24);
        for (var y = 22.0; y < s.height; y += 24) {
          canvas.drawRect(Rect.fromLTWH(0, y, s.width, 2), plank);
        }
      case CourtStyle.quadra || CourtStyle.padel || CourtStyle.saibro:
        break;
    }
  }

  void _lines(Canvas canvas, Size s) {
    final alpha = lineAlpha ?? style.lineAlpha;
    final f = Rect.fromLTRB(inset, inset, s.width - inset, s.height - inset);
    if (f.width <= 0 || f.height <= 0) return;
    final c = f.center;
    final white = Colors.white.withValues(alpha: alpha);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = white;
    double x(double p) => f.left + f.width * p;
    double y(double p) => f.top + f.height * p;
    void v(double px, [double from = 0, double to = 1]) =>
        canvas.drawLine(Offset(x(px), y(from)), Offset(x(px), y(to)), line);
    void h(double py, [double from = 0, double to = 1]) =>
        canvas.drawLine(Offset(x(from), y(py)), Offset(x(to), y(py)), line);

    switch (style) {
      case CourtStyle.areia:
        canvas.drawRect(
          f,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF1D4ED8).withValues(alpha: alpha),
        );
        _net(canvas, f, 12, const Color(0x333A2A12), 0.65);
      case CourtStyle.quadra:
        canvas
          ..drawRect(f, line)
          ..drawLine(Offset(c.dx, f.top), Offset(c.dx, f.bottom), line)
          ..drawCircle(c, f.height * 0.2, line)
          ..drawCircle(c, 2.5, Paint()..color = white);
        final area = f.height * 0.3;
        canvas
          ..drawArc(
            Rect.fromCircle(center: Offset(f.left, c.dy), radius: area),
            -math.pi / 2,
            math.pi,
            false,
            line,
          )
          ..drawArc(
            Rect.fromCircle(center: Offset(f.right, c.dy), radius: area),
            math.pi / 2,
            math.pi,
            false,
            line,
          );
      case CourtStyle.padel:
        final glass = Paint()..color = Colors.white.withValues(alpha: 0.12);
        canvas
          ..drawRect(Rect.fromLTRB(f.left, f.top, x(0.06), f.bottom), glass)
          ..drawRect(Rect.fromLTRB(x(0.94), f.top, f.right, f.bottom), glass)
          ..drawRect(f, line);
        v(0.1525);
        v(0.8475);
        h(0.5, 0.1525, 0.8475);
        _net(canvas, f, 8, const Color(0x2EFFFFFF), 0.55);
      case CourtStyle.campo:
        canvas
          ..drawRect(f, line)
          ..drawLine(Offset(c.dx, f.top), Offset(c.dx, f.bottom), line)
          ..drawCircle(c, f.height * 0.18, line)
          ..drawCircle(c, 2.5, Paint()..color = white);
        final arc = f.height * 0.12;
        canvas
          // Grandes áreas, pequenas áreas, meias-luas e gols, dos dois lados.
          ..drawRect(Rect.fromLTRB(f.left, y(0.2), x(0.15), y(0.8)), line)
          ..drawRect(Rect.fromLTRB(x(0.85), y(0.2), f.right, y(0.8)), line)
          ..drawRect(Rect.fromLTRB(f.left, y(0.36), x(0.06), y(0.64)), line)
          ..drawRect(Rect.fromLTRB(x(0.94), y(0.36), f.right, y(0.64)), line)
          ..drawArc(
            Rect.fromCircle(center: Offset(x(0.15), c.dy), radius: arc),
            -math.pi / 2,
            math.pi,
            false,
            line,
          )
          ..drawArc(
            Rect.fromCircle(center: Offset(x(0.85), c.dy), radius: arc),
            math.pi / 2,
            math.pi,
            false,
            line,
          )
          ..drawRect(Rect.fromLTRB(f.left - 7, y(0.42), f.left, y(0.58)), line)
          ..drawRect(
            Rect.fromLTRB(f.right, y(0.42), f.right + 7, y(0.58)),
            line,
          );
      case CourtStyle.saibro:
        canvas.drawRect(f, line);
        h(0.125);
        h(0.875);
        v(0.2307, 0.125, 0.875);
        v(0.7693, 0.125, 0.875);
        h(0.5, 0.2307, 0.7693);
        h(0.5, 0, 0.02);
        h(0.5, 0.98, 1);
        _net(canvas, f, 8, const Color(0x33FFFFFF), 0.6);
      case CourtStyle.ginasio:
        canvas.drawRect(f, line);
        v(1 / 3);
        v(2 / 3);
        _net(canvas, f, 8, const Color(0x2EFFFFFF), 0.55);
    }
  }

  /// Rede no meio da quadra, com a malha e os dois postes por fora.
  void _net(Canvas canvas, Rect f, double width, Color mesh, double band) {
    final over = math.min(6.0, inset * 0.5);
    final net = Rect.fromLTWH(
      f.center.dx - width / 2,
      f.top - over,
      width,
      f.height + over * 2,
    );
    final meshPaint = Paint()
      ..color = mesh
      ..strokeWidth = 1;
    for (var x = net.left; x <= net.right; x += 6) {
      canvas.drawLine(Offset(x, net.top), Offset(x, net.bottom), meshPaint);
    }
    for (var y = net.top; y <= net.bottom; y += 6) {
      canvas.drawLine(Offset(net.left, y), Offset(net.right, y), meshPaint);
    }
    canvas.drawLine(
      net.topLeft,
      net.bottomLeft,
      Paint()
        ..color = Colors.white.withValues(alpha: band)
        ..strokeWidth = 2,
    );
    final post = Paint()..color = const Color(0x59000000);
    canvas
      ..drawCircle(Offset(f.center.dx, f.top - over - 1.5), 3.5, post)
      ..drawCircle(Offset(f.center.dx, f.bottom + over + 1.5), 3.5, post);
  }

  @override
  bool shouldRepaint(CourtPainter old) =>
      old.style != style ||
      old.portrait != portrait ||
      old.inset != inset ||
      old.lines != lines ||
      old.lineAlpha != lineAlpha;
}

/// Superfície com o piso e as linhas de uma quadra atrás de [child].
class CourtSurface extends StatelessWidget {
  const CourtSurface({
    required this.style,
    this.child,
    this.portrait = false,
    this.inset = 12,
    this.lines = true,
    this.lineAlpha,
    this.borderRadius,
    super.key,
  });

  final CourtStyle style;
  final Widget? child;
  final bool portrait;
  final double inset;
  final bool lines;
  final double? lineAlpha;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget surface = RepaintBoundary(
      child: CustomPaint(
        painter: CourtPainter(
          style: style,
          portrait: portrait,
          inset: inset,
          lines: lines,
          lineAlpha: lineAlpha,
        ),
        child: child ?? const SizedBox.expand(),
      ),
    );
    if (borderRadius != null) {
      surface = ClipRRect(borderRadius: borderRadius!, child: surface);
    }
    return surface;
  }
}

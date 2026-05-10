import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport.dart';

/// Marker no formato gota com ícone do esporte ao centro.
///
/// Quando [selected] é `true`, é renderizado em escala maior e em vermelho
/// — estilo "Pin selecionado" do mockup.
class CustomSportMarker extends StatelessWidget {
  const CustomSportMarker({
    required this.sport,
    required this.selected,
    super.key,
  });

  final Sport sport;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pinColor = selected ? AppColors.error : sport.color;
    final size = selected ? 56.0 : 40.0;

    return CustomPaint(
      painter: _DropPinPainter(color: pinColor),
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.18),
          child: Center(
            child: CircleAvatar(
              radius: size * 0.35,
              backgroundColor: Colors.white,
              child: Icon(sport.icon, color: pinColor, size: size * 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropPinPainter extends CustomPainter {
  _DropPinPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Corpo arredondado (círculo)
    final circleCenter = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2;
    canvas.drawCircle(circleCenter + const Offset(0, 4), radius, shadow);
    canvas.drawCircle(circleCenter, radius, paint);

    // Ponta inferior do pin
    final path = Path()
      ..moveTo(size.width * 0.30, size.width * 0.85)
      ..lineTo(size.width * 0.50, size.height)
      ..lineTo(size.width * 0.70, size.width * 0.85)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DropPinPainter oldDelegate) =>
      oldDelegate.color != color;
}

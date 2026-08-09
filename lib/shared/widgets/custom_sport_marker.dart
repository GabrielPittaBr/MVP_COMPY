import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/sport.dart';

/// Marker no formato gota com ícone do esporte ao centro.
///
/// Quando [selected] é `true`, é renderizado em escala maior e em vermelho
/// — estilo "Pin selecionado" do mockup.
///
/// Compartilhado: o mapa (RF04) e o preview de local em "Criar evento"
/// desenham o mesmo pin, para o usuário reconhecer o local nas duas telas.
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
        // O círculo da gota é pintado no quadrado superior da caixa
        // (centro em y = size/2, altura total 1.25 * size), então o
        // ícone tem que subir junto: 0.5 / 0.625 - 1 = -0.2. Centralizar
        // na caixa inteira deixaria o ícone caído sobre a ponta.
        child: Align(
          alignment: const Alignment(0, -0.2),
          child: CircleAvatar(
            radius: size * 0.35,
            backgroundColor: Colors.white,
            child: Icon(sport.icon, color: pinColor, size: size * 0.45),
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
      ..color = Colors.black.withOpacity(0.18)
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

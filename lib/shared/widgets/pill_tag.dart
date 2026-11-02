import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Etiqueta em pílula, como "Organizador", "Você" e "Opcional".
///
/// Tem a largura do texto mesmo dentro de um `Wrap` ou de uma `Column`
/// esticada: o `Center` com `widthFactor: 1` impede que ela ocupe a linha
/// inteira, o que um `Container` com `alignment` faria.
class PillTag extends StatelessWidget {
  const PillTag({
    required this.label,
    this.color = AppColors.onSurface,
    this.height = 22,
    this.fontSize = 11,
    super.key,
  });

  final String label;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

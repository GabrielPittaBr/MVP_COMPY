import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Botão secundário com fundo neutro (ex.: "Editar perfil").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.onSurface,
        ),
        child: Text(label),
      ),
    );
  }
}

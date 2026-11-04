import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Peso visual de um [ActionButton].
enum ActionTone {
  /// Azul do COMPY: a ação principal da tela.
  filled,

  /// Fundo neutro: um estado já assumido ("Amigos", "Solicitado").
  tonal,

  /// Contorno: ação secundária ao lado da principal.
  outlined,
}

/// Botão em pílula com ícone, para ações lado a lado (perfil, listas).
///
/// [loading] troca o ícone por um indicador e desabilita o toque. O rótulo
/// fica numa linha só: quem monta a fileira cuida de dar largura a ele.
class ActionButton extends StatelessWidget {
  const ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = ActionTone.filled,
    this.loading = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ActionTone tone;
  final bool loading;

  /// 40 dp de altura visual em vez de 48, para linhas de lista. A área de
  /// toque continua com 48 dp.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double iconSize = compact ? 18 : 20;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (loading)
          SizedBox.square(
            dimension: iconSize - 2,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: iconSize),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    final VoidCallback? callback = loading ? null : onPressed;
    final Size minimumSize = Size(0, compact ? 40 : 48);
    final EdgeInsets padding =
        EdgeInsets.symmetric(horizontal: compact ? 14 : 16);
    // Parte do labelLarge do tema para herdar a Inter do resto da tela.
    final TextStyle textStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontSize: compact ? 14 : 15,
      fontWeight: FontWeight.w600,
    );
    const OutlinedBorder shape = StadiumBorder();

    return switch (tone) {
      ActionTone.filled => FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: minimumSize,
            padding: padding,
            textStyle: textStyle,
            shape: shape,
          ),
          child: content,
        ),
      ActionTone.tonal => FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceMuted,
            foregroundColor: AppColors.onSurface,
            minimumSize: minimumSize,
            padding: padding,
            textStyle: textStyle,
            shape: shape,
          ),
          child: content,
        ),
      ActionTone.outlined => OutlinedButton(
          onPressed: callback,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.outline),
            minimumSize: minimumSize,
            padding: padding,
            textStyle: textStyle,
            shape: shape,
          ),
          child: content,
        ),
    };
  }
}

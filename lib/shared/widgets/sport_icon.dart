import 'package:flutter/material.dart';

import '../models/sport.dart';

/// Ícone circular para uma modalidade esportiva.
class SportIcon extends StatelessWidget {
  const SportIcon({
    required this.sport,
    this.size = 24,
    this.background = true,
    super.key,
  });

  final Sport sport;
  final double size;
  final bool background;

  @override
  Widget build(BuildContext context) {
    if (!background) {
      return Icon(sport.icon, color: sport.color, size: size);
    }
    return Container(
      width: size * 1.6,
      height: size * 1.6,
      decoration: BoxDecoration(
        color: sport.color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(sport.icon, color: sport.color, size: size),
    );
  }
}

import 'dart:math' as math;

import '../../../../shared/models/event.dart';

/// Andamento de um evento acontecendo: o card ao vivo e a tela ao vivo
/// mostram a mesma barra e o mesmo "Faltam X" / "Passou X do previsto".
class LiveProgress {
  const LiveProgress._({
    required this.fraction,
    required this.overdue,
    required this.minutesLeft,
    required this.minutesOver,
  });

  factory LiveProgress.of(Event event, DateTime now) {
    final overdue = !now.isBefore(event.endsAt);
    final total = event.endsAt.difference(event.dateTime).inSeconds;
    final elapsed = now.difference(event.dateTime).inSeconds;
    return LiveProgress._(
      // Em atraso a barra fica cheia: o tempo previsto acabou.
      fraction:
          overdue || total <= 0 ? 1 : (elapsed / total).clamp(0, 1).toDouble(),
      overdue: overdue,
      // Arredonda para cima: com 30s restantes ainda "falta 1min".
      minutesLeft:
          overdue ? 0 : (event.endsAt.difference(now).inSeconds / 60).ceil(),
      minutesOver:
          overdue ? math.max(1, now.difference(event.endsAt).inMinutes) : 0,
    );
  }

  /// Tempo decorrido sobre a duração prevista, de 0 a 1.
  final double fraction;

  /// Passou do fim previsto (e ainda está na folga de 1h).
  final bool overdue;
  final int minutesLeft;
  final int minutesOver;
}

import 'package:intl/intl.dart';

/// Formatação amigável da duração de um evento.
///
/// A duração é armazenada em minutos (`Event.durationMinutes`), mas
/// ninguém lê "90 minutos" — as telas mostram "1h30".
abstract final class DurationFormat {
  /// "45min", "1h", "1h30" — nunca "60 minutos".
  static String short(int minutes) {
    if (minutes <= 0) return '0min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${minutes}min';
    if (rest == 0) return '${hours}h';
    return '${hours}h${rest.toString().padLeft(2, '0')}';
  }

  /// Intervalo início–fim no formato 24h: "15:00 – 16:00".
  static String timeRange(DateTime start, int durationMinutes) {
    final format = DateFormat('HH:mm');
    final end = start.add(Duration(minutes: durationMinutes));
    return '${format.format(start)} – ${format.format(end)}';
  }
}

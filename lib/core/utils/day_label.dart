import 'package:intl/intl.dart';

import '../constants/app_strings.dart';

/// Rótulo de dia para os separadores do histórico de chat.
///
/// "Hoje" e "Ontem" são relativos ao momento da leitura; qualquer data mais
/// antiga aparece por extenso, porque "3 dias atrás" obriga o leitor a fazer
/// conta de cabeça.
abstract final class DayLabel {
  /// "Hoje", "Ontem" ou "07/08/2026".
  ///
  /// [now] existe para o teste não depender do relógio — em produção fica
  /// no padrão.
  static String of(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (isSameDay(date, reference)) return AppStrings.chatToday;
    if (isSameDay(date, reference.subtract(const Duration(days: 1)))) {
      return AppStrings.chatYesterday;
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Mesmo dia do calendário, ignorando a hora.
  ///
  /// Comparar `difference().inDays` não serve: duas mensagens separadas por
  /// 2 horas podem cair em dias diferentes se atravessarem a meia-noite.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

import '../constants/app_strings.dart';
import 'day_label.dart';

/// Tempo relativo curto da central de notificações: "agora", "há 12 min",
/// "há 2 h", "ontem", "há 3 dias".
abstract final class RelativeTime {
  static String of(DateTime moment, {required DateTime now}) {
    final elapsed = now.difference(moment);
    if (DayLabel.isSameDay(moment, now)) {
      if (elapsed.inMinutes < 1) return AppStrings.timeNow;
      if (elapsed.inMinutes < 60) {
        return AppStrings.timeMinutesAgo(elapsed.inMinutes);
      }
      return AppStrings.timeHoursAgo(elapsed.inHours);
    }
    // Dias do calendário, não blocos de 24h: 23h de ontem, lido às 8h de
    // hoje, é "ontem". O arredondamento absorve um dia de 23h ou 25h.
    final days = (DateTime(now.year, now.month, now.day)
                .difference(DateTime(moment.year, moment.month, moment.day))
                .inHours /
            24)
        .round();
    if (days <= 1) return AppStrings.timeYesterday;
    return AppStrings.timeDaysAgo(days);
  }
}

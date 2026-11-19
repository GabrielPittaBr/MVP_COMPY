/// Relógio da demonstração: o painel sempre abre na quinta, 19/11, às 18:40,
/// como nas telas desenhadas.
abstract final class Demo {
  static final DateTime today = DateTime(2026, 11, 19);
  static const int now = 18 * 60 + 40;

  /// Dias com dados fictícios, a partir de hoje.
  static const int firstDay = -7;
  static const int lastDay = 21;

  static DateTime date(int day) =>
      DateTime(today.year, today.month, today.day + day);
}

const _weekdays = ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'];
const _weekdaysLong = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "qui., 19/11"
String shortDate(int day) {
  final d = Demo.date(day);
  return '${_weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}';
}

/// "qui."
String weekdayShort(int day) => _weekdays[Demo.date(day).weekday - 1];

/// "quinta-feira, 19 de novembro"
String longDate(int day) {
  final d = Demo.date(day);
  return '${_weekdaysLong[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]}';
}

/// "hoje", "amanhã" ou "qui., 19/11".
String friendlyDate(int day) => switch (day) {
  0 => 'hoje',
  1 => 'amanhã',
  -1 => 'ontem',
  _ => shortDate(day),
};

/// "18:40"
String hhmm(int minutes) => '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

/// "19:00 às 20:00"
String timeRange(int start, int end) => '${hhmm(start)} às ${hhmm(end)}';

/// "19:00–20:00"
String timeSpan(int start, int end) => '${hhmm(start)}–${hhmm(end)}';

/// "R$ 90,00"
String money(double value) {
  final cents = (value * 100).round();
  final reais = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R\$ $reais,${_two(cents % 100)}';
}

/// "Quadra 4", "Quadras 2 e 3", "Quadras 2 a 5" ou "Quadras 1, 3 e 5".
String courtsLabel(List<int> courts) {
  final sorted = [...courts]..sort();
  if (sorted.length == 1) return 'Quadra ${sorted.single}';
  final consecutive = sorted.last - sorted.first == sorted.length - 1;
  if (consecutive && sorted.length > 2) {
    return 'Quadras ${sorted.first} a ${sorted.last}';
  }
  final head = sorted.sublist(0, sorted.length - 1).join(', ');
  return 'Quadras $head e ${sorted.last}';
}

/// "1 hora", "2 horas", "1 h 30 min".
String duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? '1 hora' : '$h horas';
  return h == 0 ? '$m min' : '$h h $m min';
}

/// Iniciais para o monograma: "Arena Exemplo" vira "AE".
String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

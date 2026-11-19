import '../../../core/format.dart';
import '../../venue/data/demo_venue.dart';
import '../domain/agenda.dart';

/// Agenda fictícia: hoje é a das telas desenhadas; os outros dias saem de um
/// sorteio fixo, para a navegação entre dias ter o que mostrar.
List<AgendaItem> demoAgenda() => <AgendaItem>[
  ..._today,
  for (var day = Demo.firstDay; day <= Demo.lastDay; day++)
    if (day != 0) ..._otherDay(day),
];

AgendaItem _booking(
  String id,
  int court,
  int from,
  int to,
  String name,
  Source source, {
  double price = 90,
  String? phone,
  bool fromFreeSlot = false,
}) => AgendaItem(
  id: id,
  court: court,
  day: 0,
  start: from * 60,
  end: to * 60,
  kind: ItemKind.reserva,
  title: name,
  source: source,
  price: price * (to - from),
  phone: phone,
  sport: 'Beach tennis',
  fromFreeSlot: fromFreeSlot,
);

AgendaItem _busy(String id, int court, int from, int to, {int day = 0}) =>
    AgendaItem(
      id: id,
      court: court,
      day: day,
      start: from * 60,
      end: to * 60,
      kind: ItemKind.ocupado,
      source: Source.outroSistema,
    );

AgendaItem _block(String id, int court, int from, int to, String reason) =>
    AgendaItem(
      id: id,
      court: court,
      day: 0,
      start: from * 60,
      end: to * 60,
      kind: ItemKind.bloqueio,
      title: reason,
    );

AgendaItem _free(String id, int court) => AgendaItem(
  id: id,
  court: court,
  day: 0,
  start: 22 * 60,
  end: 23 * 60,
  kind: ItemKind.horarioLivre,
  price: 72,
  fullPrice: 90,
);

final List<AgendaItem> _today = <AgendaItem>[
  // Quadra 1
  _block('q1-aula', 1, 10, 12, 'Aula'),
  _busy('q1-o1', 1, 15, 17),
  _booking('q1-edu', 1, 17, 18, 'Grupo do Edu', Source.mensalista),
  _booking(
    'q1-tiago',
    1,
    18,
    19,
    'Tiago',
    Source.whatsapp,
    phone: '(51) 98888-1020',
  ),
  _booking('q1-paulo', 1, 19, 20, 'Paulo', Source.whatsapp),
  _busy('q1-o2', 1, 20, 22),
  _booking('q1-fer', 1, 22, 23, 'Fer', Source.balcao),
  // Quadra 2
  _busy('q2-o1', 2, 14, 15),
  _busy('q2-o2', 2, 16, 18),
  _booking(
    'q2-carla',
    2,
    18,
    19,
    'Carla',
    Source.telefone,
    phone: '(51) 97777-3344',
  ),
  const AgendaItem(
    id: 'req-marina',
    court: 2,
    day: 0,
    start: 19 * 60,
    end: 20 * 60,
    kind: ItemKind.solicitacao,
    title: 'Marina Souza',
    source: Source.compy,
    price: 90,
    phone: '(51) 90000-5678',
    sport: 'Beach tennis',
    requestedAt: '18:28',
    expiresIn: 18,
    firstVisit: true,
  ),
  _busy('q2-o3', 2, 20, 21),
  _booking('q2-bia', 2, 21, 22, 'Grupo da Bia', Source.mensalista),
  // Quadra 3
  _block('q3-manut1', 3, 8, 9, 'Manutenção'),
  _booking('q3-duda', 3, 16, 17, 'Duda', Source.whatsapp, price: 70),
  _busy('q3-o1', 3, 17, 19),
  _booking('q3-quinta', 3, 19, 20, 'Grupo Quinta', Source.mensalista),
  _busy('q3-o2', 3, 20, 21),
  _block('q3-manut2', 3, 21, 22, 'Manutenção'),
  // Quadra 4
  _busy('q4-o1', 4, 17, 18),
  _booking('q4-rafa', 4, 18, 19, 'Rafa', Source.compy, fromFreeSlot: true),
  _busy('q4-o2', 4, 19, 20),
  const AgendaItem(
    id: 'req-lucas',
    court: 4,
    day: 0,
    start: 21 * 60,
    end: 22 * 60,
    kind: ItemKind.solicitacao,
    title: 'Lucas Ferreira',
    source: Source.compy,
    price: 72,
    fullPrice: 90,
    sport: 'Futevôlei',
    requestedAt: '18:36',
    expiresIn: 26,
    fromFreeSlot: true,
  ),
  _free('q4-livre', 4),
  // Quadra 5
  _block('q5-aula', 5, 10, 11, 'Aula'),
  _busy('q5-o1', 5, 17, 19),
  _booking('q5-julio', 5, 19, 20, 'Júlio', Source.whatsapp),
  _booking('q5-gabi', 5, 20, 21, 'Gabi', Source.compy),
  _free('q5-livre', 5),
];

const _names = <String>[
  'Bruna',
  'Camila',
  'Diego',
  'Elisa',
  'Felipe',
  'Helena',
  'Igor',
  'Joana',
  'Léo',
  'Mari',
  'Nina',
  'Otávio',
  'Paula',
  'Renan',
  'Sofia',
  'Vini',
];
const _groups = <String>[
  'Grupo do Edu',
  'Grupo da Bia',
  'Grupo Quinta',
  'Turma do Léo',
  'Grupo da Nina',
];
const _sources = <Source>[
  Source.whatsapp,
  Source.whatsapp,
  Source.telefone,
  Source.balcao,
  Source.mensalista,
  Source.compy,
];

/// Sorteio fixo, igual na web e nos testes (fica abaixo de 2^53).
int _roll(int a, int b, int c) {
  var x = (a + 50) * 7919 + b * 104729 + c * 1299709;
  x = (x * 48271) % 2147483647;
  x = (x * 48271) % 2147483647;
  return x % 100;
}

List<AgendaItem> _otherDay(int day) {
  final weekday = Demo.date(day).weekday;
  final hours = DemoVenue.hours.firstWhere((h) => h.days.contains(weekday));
  final items = <AgendaItem>[];
  for (var court = 1; court <= 5; court++) {
    var hour = hours.open;
    while (hour < hours.close) {
      final busyChance = hour >= 17 ? 78 : (hour >= 12 ? 28 : 18);
      // A Quadra 5 fica livre sexta às 21h, para o exemplo do Evento do Local.
      final keepFree = day == 1 && court == 5 && hour == 21;
      if (keepFree || _roll(day, court, hour) >= busyChance) {
        hour++;
        continue;
      }
      final length =
          _roll(day + 7, court, hour) % 3 == 0 && hour + 2 <= hours.close
          ? 2
          : 1;
      final kindRoll = _roll(day + 31, court, hour);
      final id = 'd$day-q$court-$hour';
      if (kindRoll < 60) {
        items.add(_busy(id, court, hour, hour + length, day: day));
      } else if (kindRoll < 95) {
        final source = _sources[kindRoll % _sources.length];
        items.add(
          AgendaItem(
            id: id,
            court: court,
            day: day,
            start: hour * 60,
            end: (hour + length) * 60,
            kind: ItemKind.reserva,
            title: source == Source.mensalista
                ? _groups[kindRoll % _groups.length]
                : _names[(kindRoll + court) % _names.length],
            source: source,
            price: (weekday > 5 || hour >= 18 ? 90.0 : 70.0) * length,
            sport: 'Beach tennis',
          ),
        );
      } else {
        items.add(
          AgendaItem(
            id: id,
            court: court,
            day: day,
            start: hour * 60,
            end: (hour + length) * 60,
            kind: ItemKind.bloqueio,
            title: kindRoll.isEven ? 'Manutenção' : 'Aula',
          ),
        );
      }
      hour += length;
    }
  }
  return items;
}

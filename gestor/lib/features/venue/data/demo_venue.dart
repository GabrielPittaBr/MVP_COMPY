import '../domain/venue.dart';

/// Local fictício das telas: Arena Exemplo, 5 quadras de areia em Taquara/RS.
abstract final class DemoVenue {
  static const String name = 'Arena Exemplo';
  static const String city = 'Taquara/RS';
  static const String address = 'Rua Exemplo, 100 · Centro';
  static const String description =
      'Arena coberta com 5 quadras de areia, iluminação e vestiário. '
      'Aluguel de raquetes e bolas no balcão.';
  static const String whatsapp = '(51) 90000-1234';
  static const String instagram = '@arenaexemplo';
  static const List<String> sports = <String>[
    'Beach tennis',
    'Vôlei de praia',
    'Futevôlei',
  ];

  static const List<Court> courts = <Court>[
    Court(number: 1),
    Court(number: 2),
    Court(number: 3),
    Court(number: 4),
    Court(number: 5),
  ];

  static const List<PriceBand> prices = <PriceBand>[
    PriceBand(days: {1, 2, 3, 4, 5}, from: 8, to: 18, price: 70),
    PriceBand(days: {1, 2, 3, 4, 5}, from: 18, to: 23, price: 90),
    PriceBand(days: {6, 7}, from: 0, to: 24, price: 90),
  ];

  static const List<OpeningHours> hours = <OpeningHours>[
    OpeningHours('Segunda a sexta', {1, 2, 3, 4, 5}, 8, 23),
    OpeningHours('Sábado', {6}, 8, 20),
    OpeningHours('Domingo', {7}, 9, 18),
  ];

  static const List<Member> team = <Member>[
    Member(
      name: 'Carlos Mendes',
      role: Role.proprietario,
      detail: 'Entrou com Google · dono do local',
    ),
    Member(
      name: 'Ana Ribeiro',
      role: Role.atendente,
      detail: 'Desde 02/11 · último acesso hoje, 18:31',
    ),
    Member(
      name: 'Bruno Alves',
      role: Role.atendente,
      detail: 'Convite enviado hoje · vale até 26/11',
      pending: true,
    ),
  ];
}

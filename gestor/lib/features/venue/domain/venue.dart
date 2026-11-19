/// Papel de quem entra no painel. O Gerente fica para a 2ª versão.
enum Role {
  proprietario('Proprietário'),
  gerente('Gerente'),
  atendente('Atendente');

  const Role(this.label);
  final String label;

  bool get managesVenue => this != Role.atendente;
}

/// Piso da quadra (RF-P60). Cada piso tem o seu desenho.
enum CourtFloor {
  areia('Areia'),
  sintetico('Sintético'),
  grama('Grama'),
  saibro('Saibro'),
  madeira('Madeira'),
  cimento('Cimento');

  const CourtFloor(this.label);
  final String label;
}

/// Estado da quadra (RF-P61).
enum CourtStatus {
  ativa('Ativa'),
  manutencao('Em manutenção'),
  inativa('Inativa');

  const CourtStatus(this.label);
  final String label;
}

class Court {
  const Court({
    required this.number,
    this.floor = CourtFloor.areia,
    this.sports = const <String>['Beach tennis', 'Vôlei de praia', 'Futevôlei'],
    this.covered = true,
    this.lit = true,
    this.minutes = 60,
    this.status = CourtStatus.ativa,
  });

  final int number;
  final CourtFloor floor;
  final List<String> sports;
  final bool covered;
  final bool lit;
  final int minutes;
  final CourtStatus status;

  String get name => 'Quadra $number';

  /// "Areia · coberta · com iluminação".
  String get summary => <String>[
    floor.label,
    covered ? 'coberta' : 'descoberta',
    if (lit) 'com iluminação',
  ].join(' · ');

  Court copyWith({
    CourtFloor? floor,
    List<String>? sports,
    bool? covered,
    bool? lit,
    int? minutes,
    CourtStatus? status,
  }) => Court(
    number: number,
    floor: floor ?? this.floor,
    sports: sports ?? this.sports,
    covered: covered ?? this.covered,
    lit: lit ?? this.lit,
    minutes: minutes ?? this.minutes,
    status: status ?? this.status,
  );
}

/// Faixa da tabela de preços (RF-P63): dias, horário e preço por hora.
class PriceBand {
  const PriceBand({
    required this.days,
    required this.from,
    required this.to,
    required this.price,
  });

  /// Dias da semana (1 = segunda ... 7 = domingo).
  final Set<int> days;
  final int from;
  final int to;
  final double price;

  bool covers(int weekday, int hour) =>
      days.contains(weekday) && hour >= from && hour < to;

  PriceBand copyWith({double? price}) =>
      PriceBand(days: days, from: from, to: to, price: price ?? this.price);
}

/// Horário de funcionamento de um grupo de dias (RF-P62).
class OpeningHours {
  const OpeningHours(this.label, this.days, this.open, this.close);

  final String label;
  final Set<int> days;
  final int open;
  final int close;

  OpeningHours copyWith({int? open, int? close}) =>
      OpeningHours(label, days, open ?? this.open, close ?? this.close);
}

class Member {
  const Member({
    required this.name,
    required this.role,
    required this.detail,
    this.pending = false,
    this.you = false,
  });

  final String name;
  final Role role;
  final String detail;

  /// Convite enviado e ainda não aceito.
  final bool pending;
  final bool you;

  Member copyWith({Role? role}) => Member(
    name: name,
    role: role ?? this.role,
    detail: detail,
    pending: pending,
    you: you,
  );
}

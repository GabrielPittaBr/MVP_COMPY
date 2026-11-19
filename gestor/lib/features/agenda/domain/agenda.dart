/// O que ocupa (ou oferece) um intervalo de uma quadra.
enum ItemKind {
  reserva('Reservada'),
  solicitacao('Solicitada'),
  ocupado('Ocupada'),
  bloqueio('Bloqueada'),
  horarioLivre('No COMPY'),
  eventoLocal('Evento do Local');

  const ItemKind(this.label);
  final String label;

  /// Horário livre publicado ainda pode ser reservado; o resto ocupa a quadra.
  bool get holdsCourt => this != ItemKind.horarioLivre;
}

/// De onde veio a reserva (princípio 4: toda reserva guarda a origem).
enum Source {
  whatsapp('WhatsApp'),
  telefone('Telefone'),
  balcao('Balcão'),
  compy('COMPY'),
  mensalista('Mensalista'),
  outroSistema('outro sistema');

  const Source(this.label);
  final String label;
}

class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.court,
    required this.day,
    required this.start,
    required this.end,
    required this.kind,
    this.title = '',
    this.source,
    this.price,
    this.fullPrice,
    this.phone,
    this.note,
    this.sport,
    this.level,
    this.requestedAt,
    this.expiresIn,
    this.firstVisit = false,
    this.fromFreeSlot = false,
    this.spots,
    this.taken = 0,
    this.minimum,
    this.noShow = false,
  });

  final String id;

  /// Número da quadra.
  final int court;

  /// Dias a partir de hoje (0 = qui., 19/11).
  final int day;

  /// Minutos desde a meia-noite.
  final int start;
  final int end;
  final ItemKind kind;

  /// Nome do cliente ou motivo do bloqueio.
  final String title;
  final Source? source;

  /// Valor da reserva, preço no COMPY ou valor por pessoa do evento.
  final double? price;

  /// Preço cheio, quando há desconto.
  final double? fullPrice;
  final String? phone;
  final String? note;
  final String? sport;
  final String? level;

  /// Solicitação: hora do pedido e minutos que faltam para vencer.
  final String? requestedAt;
  final int? expiresIn;
  final bool firstVisit;
  final bool fromFreeSlot;

  /// Evento do Local: vagas, inscritos e mínimo para confirmar.
  final int? spots;
  final int taken;
  final int? minimum;
  final bool noShow;

  bool overlaps(int from, int to) => start < to && from < end;

  AgendaItem copyWith({
    ItemKind? kind,
    String? title,
    Source? source,
    bool? noShow,
  }) => AgendaItem(
    id: id,
    court: court,
    day: day,
    start: start,
    end: end,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    source: source ?? this.source,
    price: price,
    fullPrice: fullPrice,
    phone: phone,
    note: note,
    sport: sport,
    level: level,
    requestedAt: requestedAt,
    expiresIn: expiresIn,
    firstVisit: firstVisit,
    fromFreeSlot: fromFreeSlot,
    spots: spots,
    taken: taken,
    minimum: minimum,
    noShow: noShow ?? this.noShow,
  );
}

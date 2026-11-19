import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../venue/domain/venue.dart';
import '../../venue/presentation/venue_controller.dart';
import '../data/demo_agenda.dart';
import '../domain/agenda.dart';

class AgendaState {
  const AgendaState(
    this.items, {
    this.recoveredHours = 8,
    this.recoveredValue = 648,
  });

  final List<AgendaItem> items;

  /// Horas e valor recuperados pelo COMPY no mês (RF-P45).
  final int recoveredHours;
  final double recoveredValue;

  List<AgendaItem> dayItems(int day) => [
    for (final i in items)
      if (i.day == day) i,
  ];

  /// O que está na quadra no intervalo, contando o horário livre publicado.
  AgendaItem? at(int court, int day, int start, int end) {
    AgendaItem? offer;
    for (final i in items) {
      if (i.court != court || i.day != day || !i.overlaps(start, end)) continue;
      if (i.kind.holdsCourt) return i;
      offer = i;
    }
    return offer;
  }

  /// Solicitações do app que esperam resposta, as que vencem antes primeiro.
  List<AgendaItem> get requests => [
    for (final i in items)
      if (i.kind == ItemKind.solicitacao) i,
  ]..sort((a, b) => (a.expiresIn ?? 0).compareTo(b.expiresIn ?? 0));

  AgendaItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  AgendaState copyWith({
    List<AgendaItem>? items,
    int? recoveredHours,
    double? recoveredValue,
  }) => AgendaState(
    items ?? this.items,
    recoveredHours: recoveredHours ?? this.recoveredHours,
    recoveredValue: recoveredValue ?? this.recoveredValue,
  );
}

final agendaProvider = NotifierProvider<AgendaController, AgendaState>(
  AgendaController.new,
);

/// Agenda em memória. Faz o que as Cloud Functions vão fazer no servidor:
/// nunca deixa dois itens ocuparem a mesma quadra no mesmo horário (RF-P26).
class AgendaController extends Notifier<AgendaState> {
  var _seq = 0;

  @override
  AgendaState build() => AgendaState(demoAgenda());

  String _id(String prefix) => '$prefix-${_seq++}';

  void _set(List<AgendaItem> items) => state = state.copyWith(items: items);

  /// Primeiro item que segura a quadra no intervalo.
  AgendaItem? holder(int court, int day, int start, int end) {
    for (final i in state.items) {
      if (i.court == court &&
          i.day == day &&
          i.kind.holdsCourt &&
          i.overlaps(start, end)) {
        return i;
      }
    }
    return null;
  }

  /// Motivo para não reservar a quadra no intervalo, ou `null` se estiver
  /// livre.
  String? check(int court, int day, int start, int end) {
    final venue = ref.read(venueProvider);
    final hours = venue.hoursOf(day);
    if (start < hours.open * 60 || end > hours.close * 60) {
      return 'Nesse dia o local abre das '
          '${timeRange(hours.open * 60, hours.close * 60)}.';
    }
    final status = venue.court(court).status;
    if (status != CourtStatus.ativa) {
      return 'A Quadra $court está ${status.label.toLowerCase()}.';
    }
    if (day == 0 && start < Demo.now) {
      return 'Esse horário já passou.';
    }
    final busy = holder(court, day, start, end);
    if (busy != null) {
      return 'A Quadra $court já está ocupada das '
          '${timeRange(busy.start, busy.end)}.';
    }
    return null;
  }

  List<AgendaItem> _withoutOffers(int court, int day, int start, int end) => [
    for (final i in state.items)
      if (!(i.kind == ItemKind.horarioLivre &&
          i.court == court &&
          i.day == day &&
          i.overlaps(start, end)))
        i,
  ];

  void confirm(String id) {
    final request = state.byId(id);
    if (request == null) return;
    state = state.copyWith(
      items: [
        for (final i in state.items)
          i.id == id ? i.copyWith(kind: ItemKind.reserva) : i,
      ],
      recoveredHours:
          state.recoveredHours + (request.end - request.start) ~/ 60,
      recoveredValue: state.recoveredValue + (request.price ?? 0),
    );
  }

  void remove(String id) => _set([
    for (final i in state.items)
      if (i.id != id) i,
  ]);

  void setNoShow(String id, bool noShow) => _set([
    for (final i in state.items) i.id == id ? i.copyWith(noShow: noShow) : i,
  ]);

  /// Reserva manual (RF-P21) ou "marcar como ocupado" (RF-P24). Um horário
  /// livre publicado no mesmo intervalo sai do app (RF-P43).
  String? book({
    required int court,
    required int day,
    required int start,
    required int end,
    String name = '',
    Source source = Source.outroSistema,
    String? phone,
    double? price,
    double? fullPrice,
  }) {
    final error = check(court, day, start, end);
    if (error != null) return error;
    final busy = source == Source.outroSistema;
    _set([
      ..._withoutOffers(court, day, start, end),
      AgendaItem(
        id: _id(busy ? 'ocupado' : 'reserva'),
        court: court,
        day: day,
        start: start,
        end: end,
        kind: busy ? ItemKind.ocupado : ItemKind.reserva,
        title: name,
        source: source,
        phone: phone,
        price: price,
        fullPrice: fullPrice,
        sport: 'Beach tennis',
      ),
    ]);
    return null;
  }

  /// Bloqueia os trechos livres do intervalo (RF-P23). Reservas, solicitações
  /// e eventos no caminho impedem o bloqueio, para ninguém perder a quadra
  /// sem aviso.
  String? block({
    required List<int> courts,
    required int day,
    required int start,
    required int end,
    required String reason,
    String? note,
  }) {
    for (final court in courts) {
      for (final i in state.items) {
        if (i.court == court &&
            i.day == day &&
            i.overlaps(start, end) &&
            (i.kind == ItemKind.reserva ||
                i.kind == ItemKind.solicitacao ||
                i.kind == ItemKind.eventoLocal)) {
          final who = i.title.isEmpty ? '' : ' de ${i.title}';
          return 'A Quadra $court tem ${i.kind.label.toLowerCase()}$who das '
              '${timeRange(i.start, i.end)}. Mova ou cancele antes de '
              'bloquear.';
        }
      }
    }
    var items = state.items;
    for (final court in courts) {
      items = [
        for (final i in items)
          if (!(i.kind == ItemKind.horarioLivre &&
              i.court == court &&
              i.day == day &&
              i.overlaps(start, end)))
            i,
      ];
      final taken = [
        for (final i in items)
          if (i.court == court && i.day == day && i.overlaps(start, end)) i,
      ]..sort((a, b) => a.start.compareTo(b.start));
      var cursor = start;
      for (final gap in [
        ...taken,
        AgendaItem(
          id: '',
          court: court,
          day: day,
          start: end,
          end: end,
          kind: ItemKind.bloqueio,
        ),
      ]) {
        if (gap.start > cursor) {
          items = [
            ...items,
            AgendaItem(
              id: _id('bloqueio'),
              court: court,
              day: day,
              start: cursor,
              end: gap.start,
              kind: ItemKind.bloqueio,
              title: reason,
              note: note,
            ),
          ];
        }
        if (gap.end > cursor) cursor = gap.end;
      }
    }
    _set(items);
    return null;
  }

  /// Publica horários livres no app (RF-P40). Devolve quantos publicou.
  int publish({
    required List<int> courts,
    required int day,
    required int start,
    required int end,
    required double price,
    required double fullPrice,
  }) {
    var items = state.items;
    var count = 0;
    for (final court in courts) {
      if (check(court, day, start, end) != null) continue;
      if (state.at(court, day, start, end) != null) continue;
      items = [
        ...items,
        AgendaItem(
          id: _id('livre'),
          court: court,
          day: day,
          start: start,
          end: end,
          kind: ItemKind.horarioLivre,
          price: price,
          fullPrice: price < fullPrice ? fullPrice : null,
        ),
      ];
      count++;
    }
    _set(items);
    return count;
  }

  /// Evento do Local num horário livre (RF-P46, 2ª versão).
  String? createEvent({
    required int court,
    required int day,
    required int start,
    required int end,
    required String sport,
    required String level,
    required int spots,
    required int minimum,
    required double pricePerPerson,
  }) {
    final error = check(court, day, start, end);
    if (error != null) return error;
    _set([
      ..._withoutOffers(court, day, start, end),
      AgendaItem(
        id: _id('evento'),
        court: court,
        day: day,
        start: start,
        end: end,
        kind: ItemKind.eventoLocal,
        title: '$sport · $level',
        sport: sport,
        level: level,
        spots: spots,
        minimum: minimum,
        price: pricePerPerson,
        taken: 1,
      ),
    ]);
    return null;
  }

  /// Horários vagos de um dia, por hora cheia, a partir de agora.
  List<({int court, int hour})> freeSlots(int day) {
    final venue = ref.read(venueProvider);
    final hours = venue.hoursOf(day);
    final first = day == 0 ? (Demo.now ~/ 60) + 1 : hours.open;
    return [
      for (var h = first; h < hours.close; h++)
        for (final c in venue.activeCourts)
          if (state.at(c.number, day, h * 60, h * 60 + 60) == null)
            (court: c.number, hour: h),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/form_fields.dart';
import '../../venue/domain/venue.dart';
import '../../venue/presentation/venue_controller.dart';
import '../domain/agenda.dart';
import 'agenda_controller.dart';
import 'court_tile.dart';

/// Primeira hora cheia que ainda não começou hoje.
int get nextHour => (Demo.now ~/ 60 + 1) * 60;

/// Motivo curto para a quadra não aparecer como opção no horário.
Map<int, String> unavailableCourts(
  WidgetRef ref,
  int day,
  int start,
  int end, {
  bool offersCount = false,
}) {
  final agenda = ref.read(agendaProvider.notifier);
  final state = ref.read(agendaProvider);
  final venue = ref.read(venueProvider);
  String reason(Court court) {
    if (court.status != CourtStatus.ativa) return 'fechada';
    return switch (state.at(court.number, day, start, end)?.kind) {
      ItemKind.horarioLivre => 'no COMPY',
      ItemKind.bloqueio => 'bloqueada',
      ItemKind.solicitacao => 'solicitada',
      null => 'indisponível',
      _ => 'ocupada',
    };
  }

  return {
    for (final court in venue.courts)
      if (agenda.check(court.number, day, start, end) != null ||
          (offersCount && state.at(court.number, day, start, end) != null))
        court.number: reason(court),
  };
}

/// Nova reserva (tela 4): o pedido que chega por WhatsApp, telefone ou no
/// balcão, registrado em poucos segundos (RF-P21). A ordem dos campos segue a
/// conversa: quando, qual quadra e quem.
class BookingForm extends ConsumerStatefulWidget {
  const BookingForm({this.court, this.day = 0, this.start, super.key});

  final int? court;
  final int day;
  final int? start;

  @override
  ConsumerState<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<BookingForm> {
  late int _day = widget.day;
  late int _start = widget.start ?? nextHour;
  var _minutes = 60;
  late Set<int> _courts = {?widget.court};
  var _source = Source.whatsapp;
  var _discount = 0;
  var _showDiscount = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final court = _courts.isEmpty ? null : _courts.first;
    if (court == null) {
      setState(() => _error = 'Escolha a quadra.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escreva o nome do cliente.');
      return;
    }
    final venue = ref.read(venueProvider);
    final full = venue.price(_day, _start, _start + _minutes);
    final error = ref
        .read(agendaProvider.notifier)
        .book(
          court: court,
          day: _day,
          start: _start,
          end: _start + _minutes,
          name: name,
          source: _source,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          price: full * (100 - _discount) / 100,
          fullPrice: _discount > 0 ? full : null,
        );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    showDone(
      context,
      'Reserva salva: $name, Quadra $court, ${friendlyDate(_day)} às '
      '${hhmm(_start)}.',
    );
    closeForm(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    ref.watch(agendaProvider);
    final hours = venue.hoursOf(_day);
    final end = _start + _minutes;
    final unavailable = unavailableCourts(ref, _day, _start, end);
    final court = _courts.isEmpty ? null : _courts.first;
    final check = court == null
        ? null
        : ref.read(agendaProvider.notifier).check(court, _day, _start, end);
    final full = venue.price(_day, _start, end);
    final price = full * (100 - _discount) / 100;
    return FormFrame(
      title: 'Nova reserva',
      actions: [
        FilledButton(onPressed: _save, child: const Text('Salvar reserva')),
      ],
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Field(
                'Dia',
                DayField(
                  value: _day,
                  onChanged: (d) => setState(() {
                    _day = d;
                    _error = null;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Field(
                'Início',
                TimeField(
                  value: _start,
                  from: hours.open * 60,
                  to: hours.close * 60 - 60,
                  step: 30,
                  onChanged: (m) => setState(() {
                    _start = m;
                    _error = null;
                  }),
                ),
              ),
            ),
          ],
        ),
        Field(
          'Duração',
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 60, label: Text('1 hora')),
              ButtonSegment(value: 90, label: Text('1 h 30')),
              ButtonSegment(value: 120, label: Text('2 horas')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() {
              _minutes = s.first;
              _error = null;
            }),
          ),
        ),
        Field(
          'Quadra',
          CourtPicker(
            courts: venue.courts,
            selected: _courts,
            unavailable: unavailable,
            onChanged: (s) => setState(() {
              _courts = s;
              _error = null;
            }),
          ),
        ),
        if (court != null)
          AvailabilityNote(
            ok: check == null,
            text:
                check ??
                'Quadra $court livre das ${timeRange(_start, end)}, '
                    '${friendlyDate(_day)}.',
          ),
        Field(
          'Nome do cliente',
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ex.: Rafael Lima'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),
        Field(
          'Telefone (opcional)',
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '(51) 90000-0000'),
          ),
        ),
        Field(
          'Como chegou',
          Choices<Source>(
            options: const [Source.whatsapp, Source.telefone, Source.balcao],
            selected: _source,
            label: (s) => s.label,
            icon: sourceIcon,
            onSelected: (s) => setState(() => _source = s),
          ),
        ),
        Field(
          'Valor',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(price),
                    style: const TextStyle(
                      fontFamily: GestorTheme.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 30,
                      height: 1,
                      fontFeatures: GestorTheme.tabular,
                    ),
                  ),
                  if (_discount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      money(full),
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!_showDiscount)
                    TextButton(
                      onPressed: () => setState(() => _showDiscount = true),
                      child: const Text('Dar desconto'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pela tabela: ${money(venue.pricePerHour(_day, _start ~/ 60))} '
                'por hora',
                style: const TextStyle(
                  fontSize: 12,
                  color: GestorColors.onSurfaceVariant,
                ),
              ),
              if (_showDiscount) ...[
                const SizedBox(height: 12),
                Choices<int>(
                  options: [
                    for (var d = 0; d <= venue.discountLimit; d += 10) d,
                  ],
                  selected: _discount,
                  label: (d) => d == 0 ? 'Sem desconto' : '$d%',
                  onSelected: (d) => setState(() => _discount = d),
                ),
                const SizedBox(height: 6),
                Text(
                  'O limite de desconto é ${venue.discountLimit}%, definido '
                  'pelo proprietário.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: GestorColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) AvailabilityNote(ok: false, text: _error!),
      ],
    );
  }
}

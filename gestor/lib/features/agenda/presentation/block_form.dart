import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_fields.dart';
import '../../venue/presentation/venue_controller.dart';
import 'agenda_controller.dart';
import 'booking_form.dart';
import 'court_tile.dart';

const blockReasons = <String>[
  'Manutenção',
  'Chuva',
  'Aula',
  'Evento interno',
  'Outro',
];

/// Bloquear horário (tela 6), inclusive o dia inteiro (RF-P23).
class BlockForm extends ConsumerStatefulWidget {
  const BlockForm({this.court, this.day = 0, this.start, super.key});

  final int? court;
  final int day;
  final int? start;

  @override
  ConsumerState<BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends ConsumerState<BlockForm> {
  late Set<int> _courts = {?widget.court};
  late int _day = widget.day;
  var _wholeDay = false;
  late int _from = widget.start ?? nextHour;
  late int _to = _from + 60;
  var _reason = blockReasons.first;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (_courts.isEmpty) {
      setState(() => _error = 'Escolha pelo menos uma quadra.');
      return;
    }
    final hours = ref.read(venueProvider).hoursOf(_day);
    final from = _wholeDay ? hours.open * 60 : _from;
    final to = _wholeDay ? hours.close * 60 : _to;
    final error = ref
        .read(agendaProvider.notifier)
        .block(
          courts: _courts.toList(),
          day: _day,
          start: from,
          end: to,
          reason: _reason,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    showDone(
      context,
      '${courtsLabel(_courts.toList())} '
      '${_courts.length == 1 ? 'bloqueada' : 'bloqueadas'} '
      '${_wholeDay ? 'o dia inteiro' : 'das ${timeRange(from, to)}'}, '
      '${friendlyDate(_day)}.',
    );
    closeForm(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    ref.watch(agendaProvider);
    final hours = venue.hoursOf(_day);
    return FormFrame(
      title: 'Bloquear horário',
      actions: [FilledButton(onPressed: _save, child: const Text('Bloquear'))],
      children: [
        Field(
          'Quadra',
          CourtPicker(
            courts: venue.courts,
            selected: _courts,
            multi: true,
            onChanged: (s) => setState(() {
              _courts = s;
              _error = null;
            }),
          ),
        ),
        Field(
          'Período',
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Um horário')),
              ButtonSegment(value: true, label: Text('O dia inteiro')),
            ],
            selected: {_wholeDay},
            onSelectionChanged: (s) => setState(() {
              _wholeDay = s.first;
              _error = null;
            }),
          ),
        ),
        Field(
          'Dia',
          DayField(
            value: _day,
            onChanged: (d) => setState(() {
              _day = d;
              _error = null;
            }),
          ),
        ),
        if (!_wholeDay)
          Row(
            children: [
              Expanded(
                child: Field(
                  'Das',
                  TimeField(
                    value: _from,
                    from: hours.open * 60,
                    to: hours.close * 60 - 60,
                    onChanged: (m) => setState(() {
                      _from = m;
                      if (_to <= _from) _to = _from + 60;
                      _error = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Field(
                  'Até',
                  TimeField(
                    value: _to,
                    from: _from + 60,
                    to: hours.close * 60,
                    onChanged: (m) => setState(() {
                      _to = m;
                      _error = null;
                    }),
                  ),
                ),
              ),
            ],
          ),
        Field(
          'Motivo',
          Choices<String>(
            options: blockReasons,
            selected: _reason,
            onSelected: (r) => setState(() => _reason = r),
          ),
        ),
        Field(
          'Observação (opcional)',
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ex.: regar e nivelar a areia',
            ),
          ),
        ),
        const NoteBox(
          'Enquanto estiver bloqueado, o horário sai do app. Se já houver '
          'reserva nele, o painel avisa antes.',
        ),
        if (_error != null) AvailabilityNote(ok: false, text: _error!),
      ],
    );
  }
}

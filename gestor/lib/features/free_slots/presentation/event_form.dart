import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_fields.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../agenda/presentation/booking_form.dart';
import '../../agenda/presentation/court_tile.dart';
import '../../venue/data/demo_venue.dart';
import '../../venue/presentation/venue_controller.dart';

const _levels = ['Iniciante', 'Intermediário', 'Avançado'];

/// Evento do Local (tela 7, 2ª versão): vagas abertas a jogadores avulsos
/// do COMPY num horário que ficaria vazio (RF-P46 e RF-P47).
class EventForm extends ConsumerStatefulWidget {
  const EventForm({
    this.court = 5,
    this.day = 1,
    this.start = 21 * 60,
    super.key,
  });

  final int court;
  final int day;
  final int start;

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  late int _day = widget.day;
  late int _start = widget.start;
  late Set<int> _court = {widget.court};
  var _sport = DemoVenue.sports.first;
  var _level = _levels[1];
  var _spots = 4;
  var _minimum = 4;
  final _price = TextEditingController(text: '20');
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double get _perPerson =>
      double.tryParse(_price.text.replaceAll(',', '.').trim()) ?? 0;

  void _save() {
    if (_court.isEmpty) {
      setState(() => _error = 'Escolha a quadra.');
      return;
    }
    if (_perPerson <= 0) {
      setState(() => _error = 'Escreva o valor por pessoa.');
      return;
    }
    final error = ref
        .read(agendaProvider.notifier)
        .createEvent(
          court: _court.first,
          day: _day,
          start: _start,
          end: _start + 60,
          sport: _sport,
          level: _level,
          spots: _spots,
          minimum: _minimum,
          pricePerPerson: _perPerson,
        );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    showDone(
      context,
      'Evento criado. Ele aparece no app com o selo da ${DemoVenue.name}.',
    );
    closeForm(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    ref.watch(agendaProvider);
    final hours = venue.hoursOf(_day);
    final unavailable = unavailableCourts(ref, _day, _start, _start + 60);
    final deadline = _start - 3 * 60;
    return FormFrame(
      title: 'Evento do Local',
      actions: [
        FilledButton(onPressed: _save, child: const Text('Criar evento')),
      ],
      children: [
        const Row(children: [LaterPill()]),
        const Text(
          'Abra vagas num horário vazio para jogadores avulsos do COMPY. Se '
          'o mínimo de pessoas entrar até o prazo, o horário vira reserva.',
          style: TextStyle(color: GestorColors.onSurfaceVariant),
        ),
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
                'Horário',
                TimeField(
                  value: _start,
                  from: _day == 0 ? nextHour : hours.open * 60,
                  to: hours.close * 60 - 60,
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
          'Quadra',
          CourtPicker(
            courts: venue.courts,
            selected: _court,
            unavailable: unavailable,
            onChanged: (s) => setState(() {
              _court = s;
              _error = null;
            }),
          ),
        ),
        Field(
          'Modalidade',
          Choices<String>(
            options: DemoVenue.sports,
            selected: _sport,
            onSelected: (s) => setState(() => _sport = s),
          ),
        ),
        Field(
          'Nível',
          Choices<String>(
            options: _levels,
            selected: _level,
            onSelected: (l) => setState(() => _level = l),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Field(
                'Vagas',
                _Stepper(
                  value: _spots,
                  min: 2,
                  max: 12,
                  onChanged: (v) => setState(() {
                    _spots = v;
                    if (_minimum > v) _minimum = v;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Field(
                'Mínimo para confirmar',
                _Stepper(
                  value: _minimum,
                  min: 2,
                  max: _spots,
                  onChanged: (v) => setState(() => _minimum = v),
                ),
              ),
            ),
          ],
        ),
        Field(
          'Valor por pessoa',
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: 'R\$ '),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Com $_minimum pessoas: '),
              TextSpan(
                text: money(_perPerson * _minimum),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' pelo horário.'),
            ],
          ),
        ),
        NoteBox(
          'Se não tiver $_minimum inscritos até ${shortDate(_day)}, às '
          '${hhmm(deadline)}, o evento é cancelado e os inscritos são avisados.',
          icon: Icons.schedule,
        ),
        const FieldLabel('Como aparece no app COMPY'),
        _EventPreview(
          venueName: venue.name,
          sport: _sport,
          level: _level,
          spots: _spots,
          when: '${shortDate(_day)}, ${hhmm(_start)}',
          price: _perPerson,
        ),
        if (_error != null) AvailabilityNote(ok: false, text: _error!),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: GestorColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: GestorColors.outline),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Menos',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GestorTheme.display,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mais',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class _EventPreview extends StatelessWidget {
  const _EventPreview({
    required this.venueName,
    required this.sport,
    required this.level,
    required this.spots,
    required this.when,
    required this.price,
  });

  final String venueName;
  final String sport;
  final String level;
  final int spots;
  final String when;
  final double price;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GestorColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GestorColors.outlineVariant),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14101C3F),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const StatusPill(
              label: 'Evento do Local',
              background: GestorColors.secondaryContainer,
              foreground: GestorColors.onSecondaryContainer,
              border: GestorColors.secondary,
            ),
            const Spacer(),
            Text(
              '$spots vagas',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$sport · $level',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Monogram(name: venueName, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text('$venueName · $when')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${money(price)} por pessoa',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                disabledBackgroundColor: GestorColors.primary,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text('Participar'),
            ),
          ],
        ),
      ],
    ),
  );
}

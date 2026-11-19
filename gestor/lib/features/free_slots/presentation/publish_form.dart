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

/// Publicar horário livre (tela 5): o horário vazio vai para o app COMPY,
/// com preço promocional opcional (RF-P40 e RF-P41).
class PublishForm extends ConsumerStatefulWidget {
  const PublishForm({
    this.courts = const {},
    this.day = 0,
    this.start,
    this.repeat = false,
    super.key,
  });

  final Set<int> courts;
  final int day;
  final int? start;
  final bool repeat;

  @override
  ConsumerState<PublishForm> createState() => _PublishFormState();
}

class _PublishFormState extends ConsumerState<PublishForm> {
  late int _day = widget.day;
  late int _start = widget.start ?? 22 * 60;
  late Set<int> _courts = {...widget.courts};
  var _discount = 20;
  late var _repeat = widget.repeat;
  String? _error;

  void _save() {
    if (_courts.isEmpty) {
      setState(() => _error = 'Escolha pelo menos uma quadra livre.');
      return;
    }
    final venue = ref.read(venueProvider);
    final full = venue.price(_day, _start, _start + 60);
    final count = ref
        .read(agendaProvider.notifier)
        .publish(
          courts: _courts.toList(),
          day: _day,
          start: _start,
          end: _start + 60,
          price: full * (100 - _discount) / 100,
          fullPrice: full,
        );
    if (count == 0) {
      setState(() => _error = 'Essas quadras não estão mais livres.');
      return;
    }
    showDone(
      context,
      '${count == 1 ? '1 horário publicado' : '$count horários publicados'} '
      'no COMPY${_repeat ? ', toda ${weekdayShort(_day)}' : ''}. Os '
      'jogadores já veem no app.',
    );
    closeForm(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    ref.watch(agendaProvider);
    final hours = venue.hoursOf(_day);
    final end = _start + 60;
    final unavailable = unavailableCourts(
      ref,
      _day,
      _start,
      end,
      offersCount: true,
    );
    final chosen = _courts.difference(unavailable.keys.toSet());
    final full = venue.price(_day, _start, end);
    final price = full * (100 - _discount) / 100;
    return FormFrame(
      title: 'Publicar horário livre',
      actions: [
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.sell_outlined),
          label: Text(
            chosen.length <= 1
                ? 'Publicar no COMPY'
                : 'Publicar ${chosen.length} horários',
          ),
        ),
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
                    _courts = {};
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
                    _courts = {};
                    _error = null;
                  }),
                ),
              ),
            ),
          ],
        ),
        Field(
          'Quadras',
          CourtPicker(
            courts: venue.courts,
            selected: chosen,
            multi: true,
            unavailable: unavailable,
            onChanged: (s) => setState(() {
              _courts = s;
              _error = null;
            }),
          ),
        ),
        Field(
          'Preço no COMPY',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Choices<int>(
                options: [for (var d = 0; d <= venue.discountLimit; d += 10) d],
                selected: _discount,
                label: (d) => d == 0 ? 'Sem desconto' : '$d%',
                onSelected: (d) => setState(() => _discount = d),
              ),
              const SizedBox(height: 12),
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
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'por hora',
                    style: TextStyle(color: GestorColors.onSurfaceVariant),
                  ),
                  if (_discount > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      money(full),
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Seu limite de desconto é ${venue.discountLimit}%, definido '
                'pelo proprietário.',
                style: const TextStyle(
                  fontSize: 12,
                  color: GestorColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: SwitchListTile(
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
            title: Row(
              children: [
                Flexible(child: Text('Repetir toda ${weekdayShort(_day)}')),
                const SizedBox(width: 8),
                const LaterPill(),
              ],
            ),
            subtitle: Text(
              _repeat
                  ? 'Até qui., 25/02/2027. Dá para parar quando quiser.'
                  : 'Publica o mesmo horário todas as semanas.',
            ),
          ),
        ),
        const FieldLabel('Como aparece no app COMPY'),
        AppOfferPreview(
          venueName: venue.name,
          title: _day == 0 ? 'Livre hoje' : 'Livre ${friendlyDate(_day)}',
          detail:
              '${timeRange(_start, end)} · '
              '${chosen.isEmpty ? 'escolha as quadras' : courtsLabel(chosen.toList())}',
          price: price,
          fullPrice: _discount > 0 ? full : null,
        ),
        if (_error != null) AvailabilityNote(ok: false, text: _error!),
      ],
    );
  }
}

/// Cartão do horário livre como o jogador vê no app.
class AppOfferPreview extends StatelessWidget {
  const AppOfferPreview({
    required this.venueName,
    required this.title,
    required this.detail,
    required this.price,
    this.fullPrice,
    this.action = 'Solicitar',
    super.key,
  });

  final String venueName;
  final String title;
  final String detail;
  final double price;
  final double? fullPrice;
  final String action;

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
            Monogram(name: venueName, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venueName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Taquara · 5 quadras de areia',
                    style: TextStyle(
                      fontSize: 12,
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const StatusPill(
              label: 'Parceiro',
              background: GestorColors.primaryContainer,
              foreground: GestorColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatusPill(
          label: title,
          background: GestorColors.secondaryContainer,
          foreground: GestorColors.onSecondaryContainer,
          dot: GestorColors.secondary,
        ),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          DemoVenue.sports.join(', '),
          style: const TextStyle(
            fontSize: 12,
            color: GestorColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              money(price),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (fullPrice != null) ...[
              const SizedBox(width: 8),
              Text(
                money(fullPrice!),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: GestorColors.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                disabledBackgroundColor: GestorColors.primary,
                disabledForegroundColor: Colors.white,
              ),
              child: Text(action),
            ),
          ],
        ),
      ],
    ),
  );
}

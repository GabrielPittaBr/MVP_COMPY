import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/widgets/common.dart';
import '../../free_slots/presentation/event_form.dart';
import '../../free_slots/presentation/publish_form.dart';
import '../../venue/presentation/venue_controller.dart';
import '../domain/agenda.dart';
import 'agenda_controller.dart';
import 'block_form.dart';
import 'booking_form.dart';
import 'court_tile.dart';
import 'request_page.dart';

/// Abre um horário de uma quadra: no celular, uma folha de baixo com as
/// ações; no computador, o painel ao lado da agenda.
void openSlot(
  BuildContext context,
  WidgetRef ref, {
  required int court,
  required int day,
  required int hour,
}) {
  if (isDesktop(context)) {
    openForm(context, ref, SlotPanel(court: court, day: day, hour: hour));
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SlotActions(
        court: court,
        day: day,
        hour: hour,
        showTitle: true,
        open: (form) {
          Navigator.pop(sheet);
          openForm(context, ref, form);
        },
        done: () => Navigator.pop(sheet),
      ),
    ),
  );
}

class SlotPanel extends ConsumerWidget {
  const SlotPanel({
    required this.court,
    required this.day,
    required this.hour,
    super.key,
  });

  final int court;
  final int day;
  final int hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FormFrame(
    title: 'Quadra $court · ${hhmm(hour * 60)}',
    children: [
      SlotActions(
        court: court,
        day: day,
        hour: hour,
        open: (form) => replaceForm(context, ref, form),
        done: () => closeForm(context, ref),
      ),
    ],
  );
}

/// O que dá para fazer num horário, conforme o estado dele.
class SlotActions extends ConsumerWidget {
  const SlotActions({
    required this.court,
    required this.day,
    required this.hour,
    required this.open,
    required this.done,
    this.showTitle = false,
    super.key,
  });

  final int court;
  final int day;
  final int hour;
  final ValueChanged<Widget> open;
  final VoidCallback done;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final venue = ref.watch(venueProvider);
    final start = hour * 60;
    final item = agenda.at(court, day, start, start + 60);
    final c = venue.court(court);
    final from = item?.start ?? start;
    final to = item?.end ?? start + 60;
    final started = day < 0 || (day == 0 && from <= Demo.now);
    final notifier = ref.read(agendaProvider.notifier);

    void finish(String message) {
      showDone(context, message);
      done();
    }

    final children = <Widget>[
      if (showTitle)
        Text(
          '${c.name} · ${friendlyDate(day)}, ${timeRange(from, to)}',
          style: Theme.of(context).textTheme.titleLarge,
        )
      else
        Text(
          '${friendlyDate(day)}, ${timeRange(from, to)}',
          style: const TextStyle(color: GestorColors.onSurfaceVariant),
        ),
      SizedBox(
        height: 118,
        child: CourtTile(court: c, item: item),
      ),
      ...switch (item?.kind) {
        null when started => [
          const NoteBox('Esse horário já passou e ficou vazio.'),
        ],
        null => [
          FilledButton.icon(
            onPressed: () =>
                open(BookingForm(court: court, day: day, start: start)),
            icon: const Icon(Icons.add),
            label: const Text('Nova reserva'),
          ),
          FilledButton.tonalIcon(
            onPressed: () =>
                open(PublishForm(courts: {court}, day: day, start: start)),
            icon: const Icon(Icons.sell_outlined),
            label: const Text('Publicar no COMPY'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              notifier.book(court: court, day: day, start: start, end: to);
              finish('Quadra $court marcada como ocupada às ${hhmm(start)}.');
            },
            icon: const Icon(Icons.sync_alt),
            label: const Text('Marcar como ocupado'),
          ),
          const Text(
            'Use "Marcar como ocupado" para o horário vendido em outro '
            'sistema: ele sai do app sem pedir dados do cliente.',
            style: TextStyle(
              fontSize: 12,
              color: GestorColors.onSurfaceVariant,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                open(BlockForm(court: court, day: day, start: start)),
            icon: const Icon(Icons.block),
            label: const Text('Bloquear'),
          ),
          TextButton.icon(
            onPressed: () =>
                open(EventForm(court: court, day: day, start: start)),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Criar Evento do Local (2ª versão)'),
          ),
        ],
        ItemKind.reserva => [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  InfoRow('Cliente', item!.title),
                  InfoRow('Como chegou', item.source?.label ?? '—'),
                  if (item.phone != null) InfoRow('Telefone', item.phone!),
                  if (item.price != null)
                    InfoRow(
                      'Valor',
                      money(item.price!),
                      detail: item.fullPrice == null
                          ? null
                          : 'com desconto, de ${money(item.fullPrice!)}',
                    ),
                ],
              ),
            ),
          ),
          if (started)
            OutlinedButton.icon(
              onPressed: () {
                notifier.setNoShow(item.id, !item.noShow);
                finish(
                  item.noShow
                      ? 'Falta desfeita.'
                      : 'Falta registrada no histórico do cliente.',
                );
              },
              icon: Icon(item.noShow ? Icons.undo : Icons.person_off_outlined),
              label: Text(item.noShow ? 'Desfazer falta' : 'Marcar falta'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: GestorColors.error,
              ),
              onPressed: () async {
                if (!await _confirmCancel(context, item)) return;
                notifier.remove(item.id);
                finish(
                  item.source == Source.compy
                      ? 'Reserva cancelada. ${item.title} recebe o aviso no '
                            'app.'
                      : 'Reserva cancelada. O horário ficou livre.',
                );
              },
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Cancelar reserva'),
            ),
        ],
        ItemKind.solicitacao => [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (await refuseRequest(context, ref, item!)) done();
                  },
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    confirmRequest(context, ref, item!);
                    done();
                  },
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => open(RequestPage(id: item!.id)),
            child: const Text('Ver a solicitação completa'),
          ),
        ],
        ItemKind.ocupado => [
          const NoteBox(
            'Ocupada no outro sistema de agenda do local. Aqui só fica '
            'marcado que a quadra não está livre.',
          ),
          OutlinedButton.icon(
            onPressed: () {
              notifier.remove(item!.id);
              finish('Horário liberado.');
            },
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Liberar horário'),
          ),
        ],
        ItemKind.bloqueio => [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  InfoRow('Motivo', item!.title),
                  if (item.note != null) InfoRow('Observação', item.note!),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              notifier.remove(item.id);
              finish('Quadra $court desbloqueada.');
            },
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Desbloquear'),
          ),
        ],
        ItemKind.horarioLivre => [
          NoteBox(
            'Publicado no COMPY por ${money(item!.price ?? 0)}'
            '${item.fullPrice == null ? '' : ' (de ${money(item.fullPrice!)})'}'
            '. Se alguém reservar por outro canal, registre aqui: a '
            'publicação sai do app sozinha.',
            icon: Icons.sell_outlined,
            background: GestorColors.secondaryContainer,
            foreground: GestorColors.onSecondaryContainer,
          ),
          FilledButton.icon(
            onPressed: () =>
                open(BookingForm(court: court, day: day, start: start)),
            icon: const Icon(Icons.add),
            label: const Text('Nova reserva'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              notifier.remove(item.id);
              finish('Horário retirado do COMPY.');
            },
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Retirar do COMPY'),
          ),
        ],
        ItemKind.eventoLocal => [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  InfoRow('Evento', item!.title),
                  InfoRow(
                    'Inscritos',
                    '${item.taken} de ${item.spots}',
                    detail: 'confirma com ${item.minimum} pessoas',
                  ),
                  InfoRow('Valor', '${money(item.price ?? 0)} por pessoa'),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: GestorColors.error,
            ),
            onPressed: () {
              notifier.remove(item.id);
              finish('Evento cancelado. Os inscritos recebem o aviso.');
            },
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Cancelar evento'),
          ),
        ],
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          child,
        ],
      ],
    );
  }
}

Future<bool> _confirmCancel(BuildContext context, AgendaItem item) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva?'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reserva de ${item.title}, ${timeRange(item.start, item.end)}. '
                'O cancelamento fica no histórico com o motivo.',
              ),
              const SizedBox(height: 14),
              const TextField(decoration: InputDecoration(labelText: 'Motivo')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GestorColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    ) ??
    false;

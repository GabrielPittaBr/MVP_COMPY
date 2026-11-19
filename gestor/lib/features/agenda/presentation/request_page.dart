import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/widgets/common.dart';
import '../../venue/presentation/venue_controller.dart';
import '../domain/agenda.dart';
import 'agenda_controller.dart';
import 'court_tile.dart';

void openRequest(BuildContext context, WidgetRef ref, String id) =>
    openForm(context, ref, RequestPage(id: id));

/// Motivos curtos de recusa (RF-P31), que o jogador recebe no app.
const refuseReasons = <String>[
  'A quadra está ocupada em outro sistema',
  'A quadra vai estar em manutenção',
  'O local não abre nesse horário',
  'Outro motivo',
];

Future<String?> askRefuseReason(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (context) {
        var reason = refuseReasons.first;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Recusar solicitação'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${name.split(' ').first} recebe o motivo no app, e o '
                    'horário volta a ficar livre.',
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: reason,
                    onChanged: (value) => setState(() => reason = value!),
                    child: Column(
                      children: [
                        for (final r in refuseReasons)
                          RadioListTile<String>(
                            value: r,
                            title: Text(r),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GestorColors.error,
                ),
                onPressed: () => Navigator.pop(context, reason),
                child: const Text('Recusar'),
              ),
            ],
          ),
        );
      },
    );

/// Confirma a solicitação ali mesmo, sem abrir a ficha (três toques, no
/// máximo, desde a abertura do painel).
void confirmRequest(BuildContext context, WidgetRef ref, AgendaItem item) {
  ref.read(agendaProvider.notifier).confirm(item.id);
  showDone(
    context,
    'Reserva confirmada. ${item.title.split(' ').first} recebe o aviso no app.',
  );
}

Future<bool> refuseRequest(
  BuildContext context,
  WidgetRef ref,
  AgendaItem item,
) async {
  final reason = await askRefuseReason(context, item.title);
  if (reason == null || !context.mounted) return false;
  ref.read(agendaProvider.notifier).remove(item.id);
  showDone(
    context,
    'Solicitação recusada. ${item.title.split(' ').first} recebe o aviso.',
  );
  return true;
}

/// Ficha da solicitação vinda do app (tela 3).
class RequestPage extends ConsumerWidget {
  const RequestPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(agendaProvider.select((s) => s.byId(id)));
    if (item == null || item.kind != ItemKind.solicitacao) {
      return const FormFrame(
        title: 'Solicitação do app',
        children: [NoteBox('Esta solicitação já foi respondida.')],
      );
    }
    final court = ref.watch(venueProvider).court(item.court);
    final first = item.title.split(' ').first;
    return FormFrame(
      title: 'Solicitação do app',
      actions: [
        OutlinedButton(
          onPressed: () async {
            if (await refuseRequest(context, ref, item) && context.mounted) {
              closeForm(context, ref);
            }
          },
          child: const Text('Recusar'),
        ),
        FilledButton(
          onPressed: () {
            confirmRequest(context, ref, item);
            closeForm(context, ref);
          },
          child: const Text('Confirmar reserva'),
        ),
      ],
      children: [
        NoteBox(
          'Responda em ${item.expiresIn} min. Sem resposta, a solicitação '
          'vence e o horário volta a ficar livre.',
          icon: Icons.schedule,
          background: GestorColors.warningContainer,
          foreground: GestorColors.onWarningContainer,
        ),
        Row(
          children: [
            InitialsAvatar(item.title, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.firstVisit
                        ? 'Pelo app COMPY · primeira reserva aqui'
                        : 'Pelo app COMPY · já jogou aqui',
                    style: const TextStyle(
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (item.phone != null)
          Row(
            children: [
              const Icon(
                Icons.call_outlined,
                color: GestorColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.phone!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Telefone compartilhado com autorização',
                    style: TextStyle(
                      fontSize: 12,
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        CourtTile(
          court: court,
          item: item,
          caption: timeRange(item.start, item.end),
          minHeight: 124,
        ),
        SectionCard(
          title: 'Reserva pedida',
          gap: 0,
          children: [
            InfoRow('Quadra', '${court.name} · ${court.summary.toLowerCase()}'),
            InfoRow('Modalidade', item.sport ?? 'Beach tennis'),
            InfoRow(
              'Quando',
              '${shortDate(item.day)} · ${timeRange(item.start, item.end)}',
            ),
            InfoRow(
              'Valor',
              money(item.price ?? 0),
              detail: item.fromFreeSlot
                  ? 'horário livre publicado com desconto'
                  : 'tabela de dia útil à noite',
            ),
            InfoRow('Pedido em', 'hoje, ${item.requestedAt}'),
            const InfoRow('Cancelamento', 'sem custo até 2 h antes'),
          ],
        ),
        NoteBox(
          'Usa outro sistema de agenda? Confira se a ${court.name} está '
          'livre nele antes de confirmar para $first.',
        ),
      ],
    );
  }
}

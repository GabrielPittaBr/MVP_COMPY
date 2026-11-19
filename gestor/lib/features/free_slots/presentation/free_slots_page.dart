import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/widgets/common.dart';
import '../../agenda/domain/agenda.dart';
import '../../agenda/presentation/agenda_controller.dart';
import 'event_form.dart';
import 'free_today.dart';
import 'publish_form.dart';
import 'stories_page.dart';

/// Horários livres: o que está vago, o que já está no app e os atalhos para
/// trazer jogador novo (seção E).
class FreeSlotsPage extends ConsumerStatefulWidget {
  const FreeSlotsPage({super.key});

  @override
  ConsumerState<FreeSlotsPage> createState() => _FreeSlotsPageState();
}

class _FreeSlotsPageState extends ConsumerState<FreeSlotsPage> {
  var _day = 0;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final published =
        [
          for (final i in agenda.items)
            if (i.day >= 0 &&
                (i.kind == ItemKind.horarioLivre ||
                    i.kind == ItemKind.eventoLocal))
              i,
        ]..sort(
          (a, b) =>
              (a.day * 1440 + a.start) * 10 +
              a.court -
              ((b.day * 1440 + b.start) * 10 + b.court),
        );
    final desktop = isDesktop(context);
    final days = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var d = 0; d < 7; d++) ...[
            ChoiceChip(
              selected: d == _day,
              showCheckmark: false,
              label: Text(d <= 1 ? _cap(friendlyDate(d)) : shortDate(d)),
              onSelected: (_) => setState(() => _day = d),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
    final extras = [
      _Shortcut(
        icon: Icons.groups_outlined,
        title: 'Evento do Local',
        text:
            'Abra vagas num horário vazio para jogadores avulsos. Atingido o '
            'mínimo, vira reserva.',
        action: 'Criar evento',
        onTap: () => openForm(context, ref, const EventForm()),
      ),
      _Shortcut(
        icon: Icons.photo_camera_outlined,
        title: 'Divulgar no Instagram',
        text:
            'Uma imagem pronta com os horários livres de hoje, a logo e o '
            'link do COMPY.',
        action: 'Ver a imagem',
        onTap: () => openForm(context, ref, const StoriesPage()),
      ),
    ];
    final tip = Card(
      color: GestorColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: GestorColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quintas, das 22h às 23h, em média 3 quadras ficam '
                    'vazias. Publicar esse horário toda semana ajuda a '
                    'preencher.',
                    style: TextStyle(color: GestorColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => openForm(
                context,
                ref,
                const PublishForm(start: 22 * 60, repeat: true),
              ),
              child: const Text('Publicar toda quinta'),
            ),
          ],
        ),
      ),
    );
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        days,
        const SizedBox(height: 12),
        FreeTodayCard(day: _day),
      ],
    );
    final inApp = SectionCard(
      title: 'No app agora',
      gap: 4,
      children: [
        if (published.isEmpty)
          const Text(
            'Nenhum horário publicado. Os livres aparecem no app só quando '
            'vocês publicam.',
            style: TextStyle(color: GestorColors.onSurfaceVariant),
          ),
        for (final i in published)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              i.kind == ItemKind.eventoLocal
                  ? Icons.groups_outlined
                  : Icons.sell_outlined,
              color: GestorColors.secondary,
            ),
            title: Text(
              '${_cap(friendlyDate(i.day))}, ${hhmm(i.start)} · Quadra ${i.court}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              i.kind == ItemKind.eventoLocal
                  ? '${i.title} · ${money(i.price ?? 0)} por pessoa'
                  : '${money(i.price ?? 0)}'
                        '${i.fullPrice == null ? '' : ' (de ${money(i.fullPrice!)})'}',
            ),
            trailing: TextButton(
              onPressed: () {
                ref.read(agendaProvider.notifier).remove(i.id);
                showDone(context, 'Retirado do COMPY.');
              },
              child: const Text('Retirar'),
            ),
          ),
      ],
    );
    return PageScaffold(
      title: 'Horários livres',
      subtitle:
          'O que vocês publicam aparece no app COMPY para os jogadores da '
          'cidade.',
      mobileSubtitle: 'Publicados aparecem no app COMPY',
      actions: [
        FilledButton.icon(
          onPressed: () => openForm(context, ref, PublishForm(day: _day)),
          icon: const Icon(Icons.sell_outlined),
          label: const Text('Publicar horário livre'),
        ),
      ],
      children: desktop
          ? [
              LayoutBuilder(
                builder: (context, box) => box.maxWidth < 900
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          list,
                          const SizedBox(height: 20),
                          inApp,
                          const SizedBox(height: 20),
                          tip,
                          const SizedBox(height: 20),
                          for (final e in extras) ...[
                            e,
                            const SizedBox(height: 12),
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [list, const SizedBox(height: 20), tip],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 360,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                inApp,
                                for (final e in extras) ...[
                                  const SizedBox(height: 16),
                                  e,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ]
          : [list, inApp, tip, ...extras],
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GestorColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const LaterPill(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: GestorColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}

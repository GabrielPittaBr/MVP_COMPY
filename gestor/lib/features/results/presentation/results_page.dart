import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../free_slots/presentation/publish_form.dart';

/// Resultados do mês (2ª versão): o que o COMPY trouxe de novo, em
/// números grandes e poucos.
class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  var _month = true;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final hours = _month ? agenda.recoveredHours : agenda.recoveredHours - 6;
    final value = _month ? agenda.recoveredValue : agenda.recoveredValue - 486;
    final kpis = [
      _Kpi(
        label: 'Horas recuperadas pelo COMPY',
        value: '$hours h',
        detail: '${money(value)} em reservas vindas do app',
        highlight: true,
      ),
      _Kpi(
        label: 'Jogadores novos',
        value: _month ? '6' : '2',
        detail: 'nunca tinham reservado aqui',
      ),
      _Kpi(
        label: 'Horários livres preenchidos',
        value: _month ? '8 de 14' : '2 de 4',
        detail: _month ? '57% dos que vocês publicaram' : '50% dos publicados',
      ),
      _Kpi(
        label: 'Tempo médio de resposta',
        value: _month ? '12 min' : '9 min',
        detail: _month ? '1 solicitação venceu sem resposta' : 'nenhuma venceu',
      ),
    ];
    final toggle = SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('Semana')),
        ButtonSegment(value: true, label: Text('Mês')),
      ],
      selected: {_month},
      onSelectionChanged: (s) => setState(() => _month = s.first),
    );
    return PageScaffold(
      title: 'Resultados',
      subtitle: _month
          ? 'novembro de 2026, até ${shortDate(0)}'
          : 'semana de ${shortDate(-3)} a ${shortDate(0)}',
      back: '/mais',
      actions: [
        toggle,
        OutlinedButton.icon(
          onPressed: () => showDone(
            context,
            'Na versão final, o relatório do mês sai em PDF com a logo.',
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Baixar relatório (PDF)'),
        ),
      ],
      children: [
        const Row(
          children: [
            LaterPill(),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Números de exemplo, para mostrar como vai ficar.',
                style: TextStyle(color: GestorColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        if (!isDesktop(context)) toggle,
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 4
                : box.maxWidth >= 520
                ? 2
                : 1;
            final width = (box.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final k in kpis) SizedBox(width: width, child: k),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, box) {
            final heat = _Heatmap(
              onPublish: () => openForm(
                context,
                ref,
                const PublishForm(start: 22 * 60, repeat: true),
              ),
            );
            final origin = _Origins(compy: agenda.recoveredHours);
            if (box.maxWidth < 1000) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [heat, const SizedBox(height: 20), origin],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heat),
                const SizedBox(width: 20),
                SizedBox(width: 360, child: origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.detail,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Card(
    color: highlight ? GestorColors.primary : null,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.white : GestorColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: GestorTheme.display,
              fontWeight: FontWeight.w700,
              fontSize: 40,
              height: 1.1,
              color: highlight ? Colors.white : GestorColors.onSurface,
              fontFeatures: GestorTheme.tabular,
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              fontSize: 13,
              color: highlight
                  ? Colors.white.withValues(alpha: 0.85)
                  : GestorColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

const _days = ['Seg.', 'Ter.', 'Qua.', 'Qui.', 'Sex.', 'Sáb.', 'Dom.'];
const _levels = [
  (Color(0xFFE9EDF4), 'Até 25%'),
  (Color(0xFFC3D0F0), '26 a 50%'),
  (Color(0xFF7F96D9), '51 a 75%'),
  (Color(0xFF1F3A8A), 'Mais de 75%'),
];

/// Ocupação média das quadras (em %), ou `null` quando o local está fechado.
int? _occupancy(int day, int hour) {
  const base = [15, 20, 30, 30, 20, 20, 25, 35, 45, 80, 90, 95, 90, 75, 55];
  const saturday = [40, 55, 70, 80, 75, 60, 55, 60, 70, 85, 85, 80];
  const sunday = [30, 45, 55, 50, 40, 45, 60, 70, 65];
  if (day == 5) return hour >= 20 ? null : saturday[hour - 8];
  if (day == 6) return hour < 9 || hour >= 18 ? null : sunday[hour - 9];
  final value = base[hour - 8] + const [-5, 0, 0, -10, 5][day];
  if (day == 3 && hour == 22) return 40;
  return value.clamp(0, 100);
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Ocupação por dia e hora',
    children: [
      const Text(
        'Porcentagem das quadras ocupadas, média das últimas 4 semanas.',
        style: TextStyle(color: GestorColors.onSurfaceVariant),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 44),
                for (var h = 8; h < 23; h++)
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${h}h',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            for (var d = 0; d < 7; d++)
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _days[d],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (var h = 8; h < 23; h++)
                    _HeatCell(value: _occupancy(d, h)),
                ],
              ),
          ],
        ),
      ),
      Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (color, label) in _levels)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(painter: HatchPainter(gap: 5, width: 2)),
              ),
              SizedBox(width: 6),
              Text('Fechado', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GestorColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text.rich(
              TextSpan(
                style: TextStyle(color: GestorColors.primary),
                children: [
                  TextSpan(
                    text: 'Quintas, das 22h às 23h: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'em média 3 quadras ficam vazias. Publicar esse '
                        'horário toda semana ajuda a preencher.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.repeat),
              label: const Text('Publicar toda quinta'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Tooltip(
      message: v == null ? 'fechado' : '$v% ocupado',
      child: Container(
        width: 30,
        height: 26,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: v == null
              ? GestorColors.background
              : _levels[v <= 25
                        ? 0
                        : v <= 50
                        ? 1
                        : v <= 75
                        ? 2
                        : 3]
                    .$1,
          borderRadius: BorderRadius.circular(4),
        ),
        child: v == null
            ? const CustomPaint(painter: HatchPainter(gap: 6, width: 2))
            : null,
      ),
    );
  }
}

class _Origins extends StatelessWidget {
  const _Origins({required this.compy});

  final int compy;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Ocupadas no outro sistema', 168, GestorColors.outline),
      ('WhatsApp, telefone e balcão', 74, GestorColors.primary),
      ('Mensalistas', 36, const Color(0xFF7F96D9)),
      ('COMPY: app e horários livres', compy, GestorColors.secondary),
    ];
    final total = rows.fold(0, (n, r) => n + r.$2);
    return SectionCard(
      title: 'Reservas por origem',
      children: [
        Text(
          'Novembro, até hoje · $total reservas registradas no painel',
          style: const TextStyle(color: GestorColors.onSurfaceVariant),
        ),
        for (final (label, count, color) in rows)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: GestorTheme.tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: count / 168,
                  minHeight: 10,
                  color: color,
                  backgroundColor: GestorColors.surfaceContainer,
                ),
              ),
            ],
          ),
        const NoteBox(
          'Toda reserva guarda de onde veio. É assim que o painel mostra o que '
          'o COMPY trouxe de novo.',
        ),
      ],
    );
  }
}

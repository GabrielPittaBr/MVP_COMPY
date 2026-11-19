import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/tab_chips.dart';
import '../../agenda/presentation/court_tile.dart';
import '../domain/venue.dart';
import 'venue_controller.dart';

const _sports = <String>[
  'Beach tennis',
  'Vôlei de praia',
  'Futevôlei',
  'Futebol de areia',
  'Padel',
  'Tênis',
  'Futsal',
  'Vôlei',
  'Basquete',
  'Futebol society',
];

/// Quadras, preços e regras (só Proprietário e Gerente). Em abas, para cada
/// assunto ficar numa tela curta.
class CourtsPage extends ConsumerStatefulWidget {
  const CourtsPage({super.key});

  @override
  ConsumerState<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends ConsumerState<CourtsPage> {
  var _tab = 0;
  late VenueState _draft = ref.read(venueProvider);

  void _save() {
    ref
        .read(venueProvider.notifier)
        .update(
          (v) => v.copyWith(
            prices: _draft.prices,
            hours: _draft.hours,
            discountLimit: _draft.discountLimit,
            responseMinutes: _draft.responseMinutes,
            autoConfirm: _draft.autoConfirm,
          ),
        );
    showDone(context, 'Alterações salvas. Valem para as próximas reservas.');
  }

  @override
  Widget build(BuildContext context) {
    final save = FilledButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.check),
      label: const Text('Salvar alterações'),
    );
    return PageScaffold(
      title: 'Quadras e preços',
      subtitle: 'Só o Proprietário e o Gerente mudam estes dados.',
      back: '/mais',
      actions: [if (_tab > 0) save],
      children: [
        TabChips(
          tabs: const [
            ('Quadras', Icons.sports_volleyball_outlined),
            ('Preços', Icons.payments_outlined),
            ('Funcionamento', Icons.schedule),
            ('Regras', Icons.rule),
          ],
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
        ),
        switch (_tab) {
          0 => const _CourtsTab(),
          1 => _PricesTab(
            draft: _draft,
            onChanged: (d) => setState(() => _draft = d),
          ),
          2 => _HoursTab(
            draft: _draft,
            onChanged: (d) => setState(() => _draft = d),
          ),
          _ => _RulesTab(
            draft: _draft,
            onChanged: (d) => setState(() => _draft = d),
          ),
        },
        if (_tab > 0 && !isDesktop(context)) save,
      ],
    );
  }
}

class _CourtsTab extends ConsumerWidget {
  const _CourtsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 900
            ? 3
            : box.maxWidth >= 560
            ? 2
            : 1;
        const gap = 14.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in venue.courts)
              SizedBox(
                width: width,
                child: _CourtCard(
                  court: c,
                  onTap: () => openForm(context, ref, CourtForm(court: c)),
                ),
              ),
            SizedBox(
              width: width,
              height: 250,
              child: DashedBorder(
                radius: 14,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => openForm(
                      context,
                      ref,
                      CourtForm(
                        court: Court(
                          number: ref
                              .read(venueProvider.notifier)
                              .nextCourtNumber,
                        ),
                        isNew: true,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 32, color: GestorColors.primary),
                        SizedBox(height: 6),
                        Text(
                          'Adicionar quadra',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: GestorColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({required this.court, required this.onTap});

  final Court court;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = court.floor.style;
    final (pillBg, pillFg) = switch (court.status) {
      CourtStatus.ativa => (
        GestorColors.secondaryContainer,
        GestorColors.onSecondaryContainer,
      ),
      CourtStatus.manutencao => (
        GestorColors.warningContainer,
        GestorColors.onWarningContainer,
      ),
      CourtStatus.inativa => (
        GestorColors.surfaceContainer,
        GestorColors.onSurfaceVariant,
      ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 128,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CourtSurface(style: style, inset: 12, lineAlpha: 0.7),
                  if (court.status != CourtStatus.ativa)
                    const CustomPaint(
                      painter: HatchPainter(color: Color(0x2E101C3F), gap: 12),
                    ),
                  Align(
                    alignment: const Alignment(-0.5, 0),
                    child: Text(
                      '${court.number}',
                      style: TextStyle(
                        fontFamily: GestorTheme.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 52,
                        color: style.ink,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: StatusPill(
                      label: court.status.label,
                      background: pillBg,
                      foreground: pillFg,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    court.summary,
                    style: const TextStyle(
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${court.sports.join(', ')} · ${court.minutes} min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(onPressed: onTap, child: const Text('Editar')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editar ou cadastrar quadra (RF-P60, RF-P61 e RF-P64).
class CourtForm extends ConsumerStatefulWidget {
  const CourtForm({required this.court, this.isNew = false, super.key});

  final Court court;
  final bool isNew;

  @override
  ConsumerState<CourtForm> createState() => _CourtFormState();
}

class _CourtFormState extends ConsumerState<CourtForm> {
  late Court _court = widget.court;

  @override
  Widget build(BuildContext context) {
    final style = _court.floor.style;
    return FormFrame(
      title: widget.isNew ? 'Nova quadra' : _court.name,
      actions: [
        FilledButton(
          onPressed: () {
            ref.read(venueProvider.notifier).saveCourt(_court);
            showDone(
              context,
              widget.isNew
                  ? '${_court.name} cadastrada. Ela já aparece na agenda.'
                  : '${_court.name} atualizada.',
            );
            closeForm(context, ref);
          },
          child: Text(widget.isNew ? 'Cadastrar quadra' : 'Salvar quadra'),
        ),
      ],
      children: [
        SizedBox(
          height: 140,
          child: CourtSurface(
            style: style,
            inset: 12,
            lineAlpha: 0.7,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Text(
                _court.name,
                style: TextStyle(
                  fontFamily: GestorTheme.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 34,
                  color: style.ink,
                ),
              ),
            ),
          ),
        ),
        Field(
          'Piso',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final floor in CourtFloor.values)
                _FloorOption(
                  floor: floor,
                  selected: floor == _court.floor,
                  onTap: () =>
                      setState(() => _court = _court.copyWith(floor: floor)),
                ),
            ],
          ),
        ),
        Field(
          'Modalidades',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sport in _sports)
                FilterChip(
                  label: Text(sport),
                  selected: _court.sports.contains(sport),
                  onSelected: (on) => setState(
                    () => _court = _court.copyWith(
                      sports: on
                          ? [..._court.sports, sport]
                          : [
                              for (final s in _court.sports)
                                if (s != sport) s,
                            ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Coberta'),
                value: _court.covered,
                onChanged: (v) =>
                    setState(() => _court = _court.copyWith(covered: v)),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Com iluminação'),
                value: _court.lit,
                onChanged: (v) =>
                    setState(() => _court = _court.copyWith(lit: v)),
              ),
            ],
          ),
        ),
        Field(
          'Duração de cada horário',
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 30, label: Text('30 min')),
              ButtonSegment(value: 60, label: Text('1 hora')),
              ButtonSegment(value: 90, label: Text('1 h 30')),
              ButtonSegment(value: 120, label: Text('2 h')),
            ],
            selected: {_court.minutes},
            onSelectionChanged: (s) =>
                setState(() => _court = _court.copyWith(minutes: s.first)),
          ),
        ),
        Field(
          'Estado',
          SegmentedButton<CourtStatus>(
            showSelectedIcon: false,
            segments: [
              for (final s in CourtStatus.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_court.status},
            onSelectionChanged: (s) =>
                setState(() => _court = _court.copyWith(status: s.first)),
          ),
        ),
        NoteBox(switch (_court.status) {
          CourtStatus.ativa =>
            'Ativa: aparece na agenda e pode receber reservas e horários '
                'livres.',
          CourtStatus.manutencao =>
            'Em manutenção: a agenda fica bloqueada e a quadra sai do app até '
                'voltar a ativa.',
          CourtStatus.inativa =>
            'Inativa: some da agenda, mas o histórico de reservas é '
                'guardado.',
        }),
      ],
    );
  }
}

class _FloorOption extends StatelessWidget {
  const _FloorOption({
    required this.floor,
    required this.selected,
    required this.onTap,
  });

  final CourtFloor floor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: floor.label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              height: 56,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? GestorColors.primary
                      : GestorColors.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: CourtSurface(
                style: floor.style,
                inset: 6,
                lineAlpha: 0.6,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              floor.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? GestorColors.primary
                    : GestorColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _dayGroups = <(String, Set<int>)>[
  ('Segunda a sexta', {1, 2, 3, 4, 5}),
  ('Sábado, domingo e feriados', {6, 7}),
];

class _PricesTab extends StatelessWidget {
  const _PricesTab({required this.draft, required this.onChanged});

  final VenueState draft;
  final ValueChanged<VenueState> onChanged;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Tabela de preços',
    children: [
      Card(
        color: GestorColors.background,
        child: SwitchListTile(
          title: const Text('Mesma tabela para todas as quadras'),
          subtitle: const Text(
            'Desligue para dar um preço diferente a uma quadra.',
          ),
          value: true,
          onChanged: (_) => showDone(
            context,
            'Preço por quadra entra quando houver quadras diferentes.',
          ),
        ),
      ),
      for (final (i, band) in draft.prices.indexed)
        _PriceRow(
          days: _dayGroups
              .firstWhere(
                (g) => g.$2.containsAll(band.days),
                orElse: () => ('Todos os dias', band.days),
              )
              .$1,
          hours: band.from == 0 && band.to == 24
              ? 'o dia todo'
              : timeRange(band.from * 60, band.to * 60),
          price: band.price,
          onPrice: (p) => onChanged(
            draft.copyWith(
              prices: [
                for (final (j, b) in draft.prices.indexed)
                  j == i ? b.copyWith(price: p) : b,
              ],
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showDone(
            context,
            'Por exemplo: feriados com preço próprio. Entra junto com o '
            'calendário de feriados.',
          ),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar faixa de preço'),
        ),
      ),
      const NoteBox(
        'Mudar a tabela não altera as reservas já feitas: cada uma guarda o '
        'preço do dia em que foi marcada.',
      ),
    ],
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.days,
    required this.hours,
    required this.price,
    required this.onPrice,
  });

  final String days;
  final String hours;
  final double price;
  final ValueChanged<double> onPrice;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: GestorColors.outlineVariant),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(days, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                hours,
                style: const TextStyle(color: GestorColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 130,
          child: TextFormField(
            initialValue: price.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              prefixText: 'R\$ ',
              suffixText: '/h',
              isDense: true,
            ),
            onChanged: (v) {
              final p = double.tryParse(v.replaceAll(',', '.'));
              if (p != null) onPrice(p);
            },
          ),
        ),
      ],
    ),
  );
}

class _HoursTab extends StatelessWidget {
  const _HoursTab({required this.draft, required this.onChanged});

  final VenueState draft;
  final ValueChanged<VenueState> onChanged;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Funcionamento',
    children: [
      for (final (i, h) in draft.hours.indexed)
        Row(
          children: [
            Expanded(
              child: Text(
                h.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 110,
              child: TimeField(
                value: h.open * 60,
                from: 6 * 60,
                to: 12 * 60,
                onChanged: (m) => onChanged(
                  draft.copyWith(
                    hours: [
                      for (final (j, x) in draft.hours.indexed)
                        j == i ? x.copyWith(open: m ~/ 60) : x,
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('às'),
            ),
            SizedBox(
              width: 110,
              child: TimeField(
                value: h.close * 60,
                from: 14 * 60,
                to: 24 * 60,
                onChanged: (m) => onChanged(
                  draft.copyWith(
                    hours: [
                      for (final (j, x) in draft.hours.indexed)
                        j == i ? x.copyWith(close: m ~/ 60) : x,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      const NoteBox(
        'Feriados e dias fechados: por enquanto, bloqueie o dia inteiro na '
        'agenda. Horário especial de feriado chega na 2ª versão.',
      ),
    ],
  );
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.draft, required this.onChanged});

  final VenueState draft;
  final ValueChanged<VenueState> onChanged;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Regras das solicitações do app',
    gap: 18,
    children: [
      Field(
        'Confirmação',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Manual')),
                ButtonSegment(value: true, label: Text('Automática')),
              ],
              selected: {draft.autoConfirm},
              onSelectionChanged: (s) =>
                  onChanged(draft.copyWith(autoConfirm: s.first)),
            ),
            const SizedBox(height: 6),
            Text(
              draft.autoConfirm
                  ? 'Automática: o pedido do app vira reserva na hora. Bom para '
                        'quem usa só o COMPY.'
                  : 'Manual é o recomendado para quem também usa outro sistema '
                        'de agenda.',
              style: const TextStyle(
                fontSize: 12,
                color: GestorColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      Field(
        'Prazo para responder',
        Choices<int>(
          options: const [15, 30, 60],
          selected: draft.responseMinutes,
          label: (m) => '$m min',
          onSelected: (m) => onChanged(draft.copyWith(responseMinutes: m)),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Field(
              'Antecedência mínima',
              DropdownButtonFormField<int>(
                initialValue: 1,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 hora')),
                  DropdownMenuItem(value: 2, child: Text('2 horas')),
                  DropdownMenuItem(value: 4, child: Text('4 horas')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Field(
              'Antecedência máxima',
              DropdownButtonFormField<int>(
                initialValue: 14,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 dias')),
                  DropdownMenuItem(value: 14, child: Text('14 dias')),
                  DropdownMenuItem(value: 30, child: Text('30 dias')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ],
      ),
      Field(
        'Desconto que a equipe pode dar',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Choices<int>(
              options: const [0, 10, 20, 30],
              selected: draft.discountLimit,
              label: (d) => d == 0 ? 'Nenhum' : 'até $d%',
              onSelected: (d) => onChanged(draft.copyWith(discountLimit: d)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Só o Proprietário muda este limite.',
              style: TextStyle(
                fontSize: 12,
                color: GestorColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      Field(
        'Intervalo entre reservas',
        DropdownButtonFormField<int>(
          initialValue: 0,
          items: const [
            DropdownMenuItem(value: 0, child: Text('Sem intervalo')),
            DropdownMenuItem(value: 10, child: Text('10 minutos')),
            DropdownMenuItem(value: 15, child: Text('15 minutos')),
          ],
          onChanged: (_) {},
        ),
        trailing: const LaterPill(),
      ),
    ],
  );
}

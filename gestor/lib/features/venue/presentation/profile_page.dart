import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/theme/venue_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/tab_chips.dart';
import '../../free_slots/presentation/publish_form.dart';
import '../data/demo_venue.dart';
import 'venue_controller.dart';

const _amenities = <String>[
  'Coberta',
  'Iluminação',
  'Vestiário',
  'Estacionamento',
  'Bar',
  'Aluguel de material',
  'Acessibilidade',
];

/// Perfil do local e tema (RF-P50 a RF-P56), em abas curtas.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  var _tab = 0;
  late final _name = TextEditingController(text: ref.read(venueProvider).name);
  final _description = TextEditingController(text: DemoVenue.description);
  final _whatsapp = TextEditingController(text: DemoVenue.whatsapp);
  final _instagram = TextEditingController(text: DemoVenue.instagram);
  var _photos = 3;
  final _chosen = <String>{
    'Coberta',
    'Iluminação',
    'Vestiário',
    'Aluguel de material',
  };
  var _cancelHours = 2;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      ref.read(venueProvider.notifier).update((v) => v.copyWith(name: name));
    }
    showDone(context, 'Perfil salvo. Os jogadores já veem as mudanças no app.');
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    final save = FilledButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.check),
      label: const Text('Salvar alterações'),
    );
    return PageScaffold(
      title: 'Perfil e tema',
      subtitle: 'O que os jogadores veem sobre o local no app COMPY.',
      back: '/mais',
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showPlayerView(context, venue.name),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ver como o jogador vê'),
        ),
        if (_tab != 2) save,
      ],
      children: [
        TabChips(
          tabs: const [
            ('Informações', Icons.storefront_outlined),
            ('Fotos', Icons.photo_library_outlined),
            ('Tema', Icons.palette_outlined),
            ('Regras', Icons.gavel_outlined),
          ],
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
        ),
        ...switch (_tab) {
          0 => _info(venue),
          1 => [_photosCard()],
          2 => [_ThemeTab(current: venue.theme)],
          _ => [_policies()],
        },
        if (_tab != 2 && !isDesktop(context)) save,
      ],
    );
  }

  List<Widget> _info(VenueState venue) => [
    SectionCard(
      title: 'Logo e informações',
      gap: 16,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GestorColors.outlineVariant),
              ),
              child: Monogram(name: venue.name, size: 72),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sem logo enviada, o painel e o app mostram as iniciais do '
                    'local.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showDone(
                      context,
                      'Na versão final, aqui abre a escolha da imagem e o '
                      'recorte quadrado.',
                    ),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Enviar logo'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Text(
          'PNG, JPG ou WebP, até 2 MB e no mínimo 256 × 256 px. O recorte é '
          'quadrado.',
          style: TextStyle(fontSize: 12, color: GestorColors.onSurfaceVariant),
        ),
        Field('Nome de exibição', TextField(controller: _name)),
        Field('Descrição', TextField(controller: _description, maxLines: 3)),
        Row(
          children: [
            Expanded(
              child: Field(
                'WhatsApp',
                TextField(
                  controller: _whatsapp,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Field('Instagram', TextField(controller: _instagram)),
            ),
          ],
        ),
      ],
    ),
    SectionCard(
      title: 'Comodidades',
      trailing: const LaterPill(),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _amenities)
              FilterChip(
                label: Text(a),
                selected: _chosen.contains(a),
                onSelected: (on) =>
                    setState(() => on ? _chosen.add(a) : _chosen.remove(a)),
              ),
          ],
        ),
      ],
    ),
    SectionCard(
      title: 'Endereço e modalidades',
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, color: GestorColors.onSurfaceVariant),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '${DemoVenue.address}\n${DemoVenue.city}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in DemoVenue.sports)
              StatusPill(
                label: s,
                background: GestorColors.surfaceContainer,
                foreground: GestorColors.onSurface,
              ),
          ],
        ),
        const NoteBox(
          'Endereço, ponto no mapa e modalidades são conferidos pela equipe '
          'do COMPY.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _askChange(context),
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('Pedir alteração ao COMPY'),
          ),
        ),
      ],
    ),
  ];

  Widget _photosCard() => SectionCard(
    title: 'Fotos',
    trailing: Text(
      '$_photos de 8',
      style: const TextStyle(color: GestorColors.onSurfaceVariant),
    ),
    children: [
      LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 600 ? 4 : 2;
          final size = (box.maxWidth - 10 * (columns - 1)) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < 8; i++)
                SizedBox(
                  width: size,
                  height: size * 0.75,
                  child: i < _photos
                      ? _Photo(
                          index: i,
                          onRemove: () => setState(() => _photos--),
                        )
                      : DashedBorder(
                          radius: 12,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: i == _photos
                                ? () => setState(() => _photos++)
                                : null,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: i == _photos
                                        ? GestorColors.primary
                                        : GestorColors.outline,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Adicionar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: i == _photos
                                          ? GestorColors.primary
                                          : GestorColors.outline,
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
      ),
      const Text(
        'A primeira foto é a capa do local no app. Fotos das quadras com '
        'gente jogando chamam mais atenção.',
        style: TextStyle(fontSize: 12, color: GestorColors.onSurfaceVariant),
      ),
    ],
  );

  Widget _policies() => SectionCard(
    title: 'Regras para os jogadores',
    gap: 16,
    children: [
      Field(
        'Cancelamento sem custo até',
        DropdownButtonFormField<int>(
          initialValue: _cancelHours,
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 hora antes')),
            DropdownMenuItem(value: 2, child: Text('2 horas antes')),
            DropdownMenuItem(value: 6, child: Text('6 horas antes')),
            DropdownMenuItem(value: 24, child: Text('1 dia antes')),
          ],
          onChanged: (h) => setState(() => _cancelHours = h ?? 2),
        ),
      ),
      Field(
        'Faltas',
        TextFormField(
          initialValue:
              'Na 1ª falta sem aviso, o cliente recebe uma advertência. Na '
              '2ª, o horário é cobrado.',
          maxLines: 2,
        ),
      ),
      Field(
        'Regras da casa',
        TextFormField(
          initialValue:
              'Chegue 10 minutos antes. Calçado só na área do bar. Proibido '
              'vidro nas quadras.',
          maxLines: 3,
        ),
      ),
      const NoteBox(
        'O jogador vê estas regras antes de pedir a reserva no app.',
      ),
    ],
  );

  Future<void> _askChange(BuildContext context) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedir alteração'),
        content: const SizedBox(
          width: 420,
          child: TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex.: abrimos uma quadra de futevôlei nova.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar ao COMPY'),
          ),
        ],
      ),
    );
    if (sent == true && context.mounted) {
      showDone(context, 'Pedido enviado. A equipe do COMPY responde por aqui.');
    }
  }

  void _showPlayerView(BuildContext context, String name) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Como o jogador vê'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [LaterPill()]),
            const SizedBox(height: 12),
            AppOfferPreview(
              venueName: name,
              title: 'Livre hoje',
              detail: '22:00 às 23:00 · Quadras 2 e 3',
              price: 72,
              fullPrice: 90,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.index, required this.onRemove});

  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CourtSurface(
        style: CourtStyle.areia,
        inset: 10,
        lineAlpha: 0.7,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              index == 0 ? 'Capa' : 'Foto ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      Positioned(
        top: 4,
        right: 4,
        child: IconButton.filledTonal(
          tooltip: 'Tirar foto',
          iconSize: 18,
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ),
    ],
  );
}

/// Escolha do tema (RF-P52): cada opção mostra o menu como vai ficar.
class _ThemeTab extends ConsumerWidget {
  const _ThemeTab({required this.current});

  final VenueTheme current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(venueProvider.select((v) => v.name));
    return SectionCard(
      title: 'Tema do painel',
      children: [
        const Text(
          'O tema segue a modalidade principal do local, beach tennis. Vocês '
          'podem trocar por outro da lista: a mudança aparece na hora.',
        ),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 6
                : box.maxWidth >= 560
                ? 3
                : 2;
            final width = (box.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (final t in VenueTheme.values)
                  SizedBox(
                    width: width,
                    child: _ThemeOption(
                      theme: t,
                      venueName: name,
                      selected: t == current,
                      onTap: () {
                        ref
                            .read(venueProvider.notifier)
                            .update((v) => v.copyWith(theme: t));
                        showDone(context, 'Tema ${t.label} aplicado.');
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const NoteBox(
          'O tema muda a moldura do painel, o login da equipe e as imagens de '
          'divulgação. A agenda e os formulários não mudam, para ficarem '
          'legíveis em qualquer tema.',
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.venueName,
    required this.selected,
    required this.onTap,
  });

  final VenueTheme theme;
  final String venueName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Tema ${theme.label}',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 210,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? GestorColors.primary
                    : GestorColors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: CourtSurface(
              style: theme.court,
              portrait: true,
              inset: 10,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Monogram(name: venueName, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GestorTheme.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: theme.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final (i, item) in const [
                      'Hoje',
                      'Agenda',
                      'Horários livres',
                    ].indexed)
                      Container(
                        height: 26,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: i == 0 ? theme.selected : Colors.transparent,
                          border: i == 0
                              ? Border(
                                  left: BorderSide(
                                    color: theme.accent,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.only(left: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: theme.ink,
                          ),
                        ),
                      ),
                    const Spacer(),
                    CompyBadge(color: theme.ink2),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                theme.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: GestorColors.primary,
                ),
                const Text(
                  ' em uso',
                  style: TextStyle(fontSize: 12, color: GestorColors.primary),
                ),
              ],
            ],
          ),
          Text(
            theme.sports,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: GestorColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/venue/domain/venue.dart';
import '../../features/venue/presentation/venue_controller.dart';
import '../layout.dart';
import '../theme/court_painter.dart';
import '../theme/gestor_colors.dart';
import '../theme/gestor_theme.dart';
import '../theme/venue_theme.dart';
import '../widgets/common.dart';

typedef Destination = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  String route,
  bool owner,
});

/// Itens do menu. Os do proprietário somem para o atendente (seção 4).
const List<Destination> destinations = [
  (
    label: 'Hoje',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    route: '/hoje',
    owner: false,
  ),
  (
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    route: '/agenda',
    owner: false,
  ),
  (
    label: 'Horários livres',
    icon: Icons.sell_outlined,
    selectedIcon: Icons.sell,
    route: '/livres',
    owner: false,
  ),
  (
    label: 'Resultados',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    route: '/resultados',
    owner: true,
  ),
  (
    label: 'Perfil e tema',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    route: '/perfil',
    owner: true,
  ),
  (
    label: 'Quadras e preços',
    icon: Icons.sports_volleyball_outlined,
    selectedIcon: Icons.sports_volleyball,
    route: '/quadras',
    owner: true,
  ),
  (
    label: 'Equipe',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    route: '/equipe',
    owner: true,
  ),
  (
    label: 'Plano',
    icon: Icons.workspace_premium_outlined,
    selectedIcon: Icons.workspace_premium,
    route: '/plano',
    owner: true,
  ),
  (
    label: 'Ajuda',
    icon: Icons.help_outline,
    selectedIcon: Icons.help,
    route: '/ajuda',
    owner: false,
  ),
];

/// Barra inferior do celular: Hoje, Agenda, Livres e Mais (seção 7).
const List<Destination> _bottom = [
  (
    label: 'Hoje',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    route: '/hoje',
    owner: false,
  ),
  (
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    route: '/agenda',
    owner: false,
  ),
  (
    label: 'Livres',
    icon: Icons.sell_outlined,
    selectedIcon: Icons.sell,
    route: '/livres',
    owner: false,
  ),
  (
    label: 'Mais',
    icon: Icons.menu,
    selectedIcon: Icons.menu,
    route: '/mais',
    owner: false,
  ),
];

/// Sair do painel e voltar ao login.
void signOut(BuildContext context, WidgetRef ref) {
  ref.read(panelProvider.notifier).close();
  ref.read(sessionProvider.notifier).signOut();
  context.go('/entrar');
}

/// Troca o papel na demonstração, para ver o painel como o outro perfil.
void switchRole(BuildContext context, WidgetRef ref) {
  final current = ref.read(sessionProvider)?.role ?? Role.atendente;
  ref.read(panelProvider.notifier).close();
  ref
      .read(sessionProvider.notifier)
      .signIn(
        current == Role.proprietario ? Role.atendente : Role.proprietario,
      );
  context.go('/hoje');
}

class GestorShell extends ConsumerWidget {
  const GestorShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(venueProvider.select((v) => v.theme));
    if (!isDesktop(context)) {
      final index = _bottom.indexWhere((d) => location.startsWith(d.route));
      return Scaffold(
        body: child,
        bottomNavigationBar: _BottomBar(
          theme: theme,
          selected: index < 0 ? 3 : index,
        ),
      );
    }
    final panel = ref.watch(panelProvider);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 256,
            child: _Sidebar(theme: theme, location: location),
          ),
          Expanded(child: child),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.centerLeft,
            child: panel == null
                ? const SizedBox.shrink()
                : Container(
                    width: 440,
                    decoration: const BoxDecoration(
                      color: GestorColors.surface,
                      border: Border(
                        left: BorderSide(color: GestorColors.outlineVariant),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x14101C3F),
                          blurRadius: 24,
                          offset: Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: PanelScope(child: panel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.theme, required this.selected});

  final VenueTheme theme;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CourtSurface(
      style: theme.court,
      lines: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (i, d) in _bottom.indexed)
                Expanded(
                  child: _BottomItem(
                    destination: d,
                    theme: theme,
                    selected: i == selected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.theme,
    required this.selected,
  });

  final Destination destination;
  final VenueTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: destination.label,
    excludeSemantics: true,
    child: InkWell(
      onTap: () => context.go(destination.route),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            Positioned(
              top: 0,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? theme.selected : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: theme.ink,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.theme, required this.location});

  final VenueTheme theme;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final name = ref.watch(venueProvider.select((v) => v.name));
    final owner = session?.role.managesVenue ?? false;
    final items = [
      for (final d in destinations)
        if (owner || !d.owner) d,
    ];
    return CourtSurface(
      style: theme.court,
      portrait: true,
      inset: 16,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 36, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Monogram(name: name, size: 56),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: GestorTheme.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 28,
                            height: 1.05,
                            color: theme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Painel do Local',
                          style: TextStyle(fontSize: 14, color: theme.ink2),
                        ),
                      ],
                    ),
                  ),
                  for (final d in items) ...[
                    if (d.route == '/perfil')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(36, 16, 16, 6),
                        child: Text(
                          'Local',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.ink2,
                          ),
                        ),
                      ),
                    _SideItem(
                      destination: d,
                      theme: theme,
                      selected: location.startsWith(d.route),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 28, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (owner) ...[
                          Text(
                            'Plano Pro · grátis até 30/04/2027',
                            style: TextStyle(fontSize: 12, color: theme.ink2),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          session?.name ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.ink,
                          ),
                        ),
                        Text(
                          session?.role.label ?? '',
                          style: TextStyle(fontSize: 13, color: theme.ink2),
                        ),
                        const SizedBox(height: 10),
                        _SideButton(
                          icon: Icons.swap_horiz,
                          label: owner
                              ? 'Ver como Atendente'
                              : 'Ver como Proprietário',
                          color: theme.ink,
                          onTap: () => switchRole(context, ref),
                        ),
                        _SideButton(
                          icon: Icons.logout,
                          label: 'Sair',
                          color: theme.ink,
                          onTap: () => signOut(context, ref),
                        ),
                        const SizedBox(height: 14),
                        CompyBadge(color: theme.ink2),
                      ],
                    ),
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

class _SideItem extends ConsumerWidget {
  const _SideItem({
    required this.destination,
    required this.theme,
    required this.selected,
  });

  final Destination destination;
  final VenueTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? theme.selected : Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(panelProvider.notifier).close();
          context.go(destination.route);
        },
        hoverColor: theme.ink.withValues(alpha: 0.06),
        child: SizedBox(
          height: 48,
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: theme.accent),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 16),
                child: Row(
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 22,
                      color: selected ? theme.ink : theme.ink2,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        destination.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? theme.ink : theme.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-10, 0),
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );
}

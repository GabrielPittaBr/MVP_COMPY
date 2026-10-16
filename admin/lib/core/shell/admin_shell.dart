import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/admin_auth_feature.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_court.dart';

bool usesDesktopAdminNavigation(double width) => width >= 840;

typedef _Destination = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  String route,
});

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.controller,
    required this.location,
    required this.child,
    super.key,
  });

  final AdminAuthController controller;
  final String location;
  final Widget child;

  static const _navigation = <_Destination>[
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      route: '/dashboard',
    ),
    (
      label: 'Locais',
      icon: Icons.place_outlined,
      selectedIcon: Icons.place,
      route: '/places',
    ),
    (
      label: 'Usuários',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      route: '/users',
    ),
  ];

  int get _selectedIndex {
    final index = _navigation.indexWhere((item) => location.startsWith(item.route));
    return index < 0 ? 0 : index;
  }

  Future<void> _logout(BuildContext context) async {
    await controller.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final desktop = usesDesktopAdminNavigation(
      MediaQuery.sizeOf(context).width,
    );
    final selectedIndex = _selectedIndex;
    final navigation = AdminCourtSurface(
      minHalfway: 380,
      child: _AdminNavigation(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(_navigation[index].route),
        onLogout: () => _logout(context),
        email: controller.session?.email,
      ),
    );

    if (desktop) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 256, child: navigation),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      drawer: Drawer(child: navigation),
      appBar: AppBar(
        title: Text(_navigation[selectedIndex].label),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.email,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(36, 40, 24, 48),
            child: AdminWordmark(),
          ),
          for (final (index, item) in AdminShell._navigation.indexed)
            _NavigationItem(
              destination: item,
              selected: index == selectedIndex,
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onDestinationSelected(index);
              },
            ),
          const Spacer(),
          if (email != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 24, 4),
              child: Text(
                email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onLogout,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Sair'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item da navegação. O selecionado acende a linha lateral da quadra em verde.
class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.78);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withValues(alpha: 0.06),
        focusColor: Colors.white.withValues(alpha: 0.16),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: SizedBox(
          height: 52,
          child: Row(
            children: <Widget>[
              // Fica exatamente sobre a linha lateral desenhada na superfície.
              Container(
                width: 4,
                margin: const EdgeInsets.only(
                  left: AdminCourtSurface.lineInset - 2,
                ),
                color: selected ? AdminColors.courtLine : Colors.transparent,
              ),
              const SizedBox(width: 18),
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Respiro das páginas: mais largo com a navegação fixa do desktop.
EdgeInsets adminPagePadding(BuildContext context) =>
    usesDesktopAdminNavigation(MediaQuery.sizeOf(context).width)
    ? const EdgeInsets.fromLTRB(40, 36, 40, 48)
    : const EdgeInsets.fromLTRB(20, 24, 20, 32);

class AdminRoutePlaceholder extends StatelessWidget {
  const AdminRoutePlaceholder({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

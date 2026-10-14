import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/admin_auth_feature.dart';

bool usesDesktopAdminNavigation(double width) => width >= 840;

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

  static const _navigation = <({String label, IconData icon, String route})>[
    (label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    (label: 'Locais', icon: Icons.place_outlined, route: '/places'),
    (label: 'Usuários', icon: Icons.people_outline, route: '/users'),
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
    return LayoutBuilder(
      builder: (context, _) {
        final desktop = usesDesktopAdminNavigation(MediaQuery.sizeOf(context).width);
        final selectedIndex = _selectedIndex;
        final navigation = _AdminNavigation(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => context.go(_navigation[index].route),
          onLogout: () => _logout(context),
          email: controller.session?.email,
          permanent: desktop,
        );

        return Scaffold(
          drawer: desktop ? null : Drawer(child: navigation),
          appBar: AppBar(
            title: Text(_navigation[selectedIndex].label),
            actions: <Widget>[
              if (controller.session?.email case final email?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(child: Text(email)),
                ),
              IconButton(
                tooltip: 'Sair',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Row(
            children: <Widget>[
              if (desktop) navigation,
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.email,
    required this.permanent,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final String? email;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final rail = NavigationRail(
      extended: permanent,
      selectedIndex: selectedIndex,
      labelType: permanent ? null : NavigationRailLabelType.all,
      onDestinationSelected: onDestinationSelected,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('COMPY Admin'),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (email != null) Padding(padding: const EdgeInsets.all(12), child: Text(email!)),
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.place_outlined),
          selectedIcon: Icon(Icons.place),
          label: Text('Locais'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Usuários'),
        ),
      ],
    );
    return permanent ? rail : SafeArea(child: rail);
  }
}

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

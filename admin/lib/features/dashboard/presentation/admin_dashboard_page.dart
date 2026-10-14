import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_dashboard_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({this.repository, super.key});

  final AdminDashboardRepository? repository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AdminDashboardRepository _repository =
      widget.repository ?? FirebaseAdminDashboardRepository();
  late Future<AdminDashboardMetrics> _metrics = _repository.loadMetrics();

  void _retry() {
    setState(() {
      _metrics = _repository.loadMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text('Visão geral', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        FutureBuilder<AdminDashboardMetrics>(
          future: _metrics,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DashboardError(onRetry: _retry);
            }
            if (!snapshot.hasData) return const _DashboardSkeleton();
            final metrics = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 920
                    ? 3
                    : constraints.maxWidth >= 580
                    ? 2
                    : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: columns == 1 ? 3.3 : 1.9,
                  children: <Widget>[
                    _MetricCard(
                      title: 'Usuários cadastrados',
                      value: metrics.profileCount,
                      icon: Icons.people_outline,
                      help: 'Total de perfis cadastrados no Firestore; pode diferir das contas do Firebase Auth.',
                    ),
                    _MetricCard(
                      title: 'Locais ativos',
                      value: metrics.activePlaceCount,
                      icon: Icons.place_outlined,
                    ),
                    _MetricCard(
                      title: 'Locais inativos',
                      value: metrics.inactivePlaceCount,
                      icon: Icons.location_off_outlined,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 28),
        Text('Atalhos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _ShortcutButton(
              label: 'Cadastrar local',
              icon: Icons.add_location_alt_outlined,
              onPressed: () => context.go('/places/new'),
            ),
            _ShortcutButton(
              label: 'Ver locais inativos',
              icon: Icons.location_off_outlined,
              onPressed: () => context.go('/places?status=inactive'),
            ),
            _ShortcutButton(
              label: 'Buscar usuário',
              icon: Icons.person_search_outlined,
              onPressed: () => context.go('/users'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.help,
  });

  final String title;
  final int value;
  final IconData icon;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 32, semanticLabel: title),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    value.toString(),
                    semanticsLabel: '$title: $value',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (help != null)
                    Tooltip(
                      message: help!,
                      child: Semantics(
                        label: help,
                        child: const Text('Contagem de perfis Firestore'),
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

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando indicadores do painel',
    child: SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Não foi possível carregar os indicadores.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

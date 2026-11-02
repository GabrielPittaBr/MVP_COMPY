import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/shell/admin_shell.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Text('Visão geral', style: textTheme.headlineMedium),
        const SizedBox(height: 24),
        FutureBuilder<AdminDashboardMetrics>(
          future: _metrics,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DashboardError(onRetry: _retry);
            }
            if (!snapshot.hasData) return const _DashboardSkeleton();
            final metrics = snapshot.data!;
            final users = _UsersMetric(value: metrics.profileCount);
            final places = _PlacesMetric(
              active: metrics.activePlaceCount,
              inactive: metrics.inactivePlaceCount,
            );
            final events = _EventsMetric(
              total: metrics.eventCount,
              upcoming: metrics.upcomingEventCount,
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      users,
                      const SizedBox(height: 16),
                      places,
                      const SizedBox(height: 16),
                      events,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(flex: 2, child: users),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: places),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    events,
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 40),
        Text('Atalhos', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _ShortcutButton(
              label: 'Ver eventos',
              icon: Icons.event_outlined,
              onPressed: () => context.go('/events'),
            ),
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

class _UsersMetric extends StatelessWidget {
  const _UsersMetric({required this.value});

  final int value;

  static const _help =
      'Total de perfis cadastrados no Firestore; pode diferir das contas do Firebase Auth.';

  @override
  Widget build(BuildContext context) => _MetricPanel(
    title: 'Usuários cadastrados',
    icon: Icons.people_outline,
    children: <Widget>[
      _MetricNumber(value: value, semanticsLabel: 'Usuários cadastrados'),
      const SizedBox(height: 12),
      Tooltip(
        message: _help,
        child: Semantics(
          label: _help,
          child: const Text('Contagem de perfis Firestore'),
        ),
      ),
    ],
  );
}

/// Locais ativos e inativos lado a lado, com a proporção entre eles.
class _PlacesMetric extends StatelessWidget {
  const _PlacesMetric({required this.active, required this.inactive});

  final int active;
  final int inactive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _MetricPanel(
      title: 'Locais esportivos',
      icon: Icons.place_outlined,
      children: <Widget>[
        Wrap(
          spacing: 40,
          runSpacing: 16,
          children: <Widget>[
            _LegendCount(
              value: active,
              label: 'ativos',
              semanticsLabel: 'Locais ativos',
              color: colors.secondary,
            ),
            _LegendCount(
              value: inactive,
              label: 'inativos',
              semanticsLabel: 'Locais inativos',
              color: colors.outline,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (active > 0)
                  Expanded(
                    flex: active,
                    child: ColoredBox(color: colors.secondary),
                  ),
                if (active > 0 && inactive > 0) const SizedBox(width: 2),
                if (inactive > 0 || active == 0)
                  Expanded(
                    flex: inactive == 0 ? 1 : inactive,
                    child: ColoredBox(color: colors.outline),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Só os locais ativos aparecem no mapa do app.'),
      ],
    );
  }
}

/// Contagem com a legenda colorida que a identifica.
class _LegendCount extends StatelessWidget {
  const _LegendCount({
    required this.value,
    required this.label,
    required this.semanticsLabel,
    required this.color,
  });

  final int value;
  final String label;
  final String semanticsLabel;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _MetricNumber(value: value, semanticsLabel: semanticsLabel),
      const SizedBox(height: 6),
      ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    ],
  );
}

/// Eventos que ainda vão acontecer e o total já criado no app.
class _EventsMetric extends StatelessWidget {
  const _EventsMetric({required this.total, required this.upcoming});

  final int total;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _MetricPanel(
      title: 'Eventos esportivos',
      icon: Icons.event_outlined,
      children: <Widget>[
        Wrap(
          spacing: 40,
          runSpacing: 16,
          children: <Widget>[
            _LegendCount(
              value: upcoming,
              label: 'agendados',
              semanticsLabel: 'Eventos agendados',
              color: colors.primary,
            ),
            _LegendCount(
              value: total,
              label: 'no total',
              semanticsLabel: 'Eventos no total',
              color: colors.outline,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Encerrados saem das listas do app, mas continuam aqui até serem excluídos.',
        ),
      ],
    );
  }
}

class _MetricNumber extends StatelessWidget {
  const _MetricNumber({required this.value, required this.semanticsLabel});

  final int value;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Text(
    value.toString(),
    semanticsLabel: '$semanticsLabel: $value',
    style: Theme.of(context).textTheme.displaySmall,
  );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
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
    child: const SizedBox(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Não foi possível carregar os indicadores.'),
          const SizedBox(height: 12),
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

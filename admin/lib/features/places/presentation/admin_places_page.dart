import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/shell/admin_shell.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_status_pill.dart';
import '../data/admin_places_repository.dart';
import 'admin_places_controller.dart';

class AdminPlacesPage extends StatefulWidget {
  const AdminPlacesPage({
    this.repository,
    this.initialStatus = AdminPlaceStatusFilter.all,
    super.key,
  });

  final AdminPlacesRepository? repository;
  final AdminPlaceStatusFilter initialStatus;

  @override
  State<AdminPlacesPage> createState() => _AdminPlacesPageState();
}

class _AdminPlacesPageState extends State<AdminPlacesPage> {
  late final AdminPlacesController _controller = AdminPlacesController(
    widget.repository ?? FirebaseAdminPlacesRepository(),
    initialStatus: widget.initialStatus,
  )..addListener(_onChanged);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cityController.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _updateFilters(AdminPlacesFilters filters) =>
      _controller.updateFilters(filters);

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    // Lista vazia vinda do cache significa falta de conexão sem nada salvo,
    // não ausência de locais cadastrados.
    final offlineWithoutCache =
        state.isFromCache && state.places.isEmpty && !state.isLoading;
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Locais Esportivos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            FilledButton.icon(
              onPressed: () => context.go('/places/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Cadastrar local'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildFilters(state.filters),
        if (state.isFromCache && !offlineWithoutCache) ...<Widget>[
          const SizedBox(height: 12),
          const _OfflineBanner(),
        ],
        const SizedBox(height: 16),
        if (state.isLoading && state.places.isEmpty)
          const _PlacesSkeleton()
        else if (state.error != null && state.places.isEmpty)
          _PlacesError(onRetry: _controller.retry)
        else if (offlineWithoutCache)
          _PlacesError(
            onRetry: _controller.retry,
            message: 'Sem conexão e nenhum local salvo neste navegador.',
          )
        else if (state.places.isEmpty)
          _PlacesEmpty(filters: state.filters)
        else ...<Widget>[
          if (state.error != null) _InlineError(onRetry: _controller.retry),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (final (index, place) in state.places.indexed) ...<Widget>[
                  if (index > 0) const Divider(),
                  _PlaceTile(
                    place: place,
                    onTap: () =>
                        context.go('/places/${Uri.encodeComponent(place.id)}'),
                  ),
                ],
              ],
            ),
          ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.hasMore && !state.isLoadingMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton(
                  onPressed: _controller.loadNextPage,
                  child: const Text('Carregar mais locais'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildFilters(AdminPlacesFilters filters) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Buscar por nome',
        textField: true,
        child: SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar por nome',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _updateFilters(
                  _controller.state.filters.copyWith(
                    namePrefix: normalizeAdminSearch(value),
                  ),
                );
              });
            },
          ),
        ),
      ),
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Filtro: Status',
        child: SizedBox(
          width: 190,
          child: DropdownButtonFormField<AdminPlaceStatusFilter>(
            key: ValueKey<AdminPlaceStatusFilter>(filters.status),
            initialValue: filters.status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const <DropdownMenuItem<AdminPlaceStatusFilter>>[
              DropdownMenuItem(
                value: AdminPlaceStatusFilter.all,
                child: Text('Todos'),
              ),
              DropdownMenuItem(
                value: AdminPlaceStatusFilter.active,
                child: Text('Ativos'),
              ),
              DropdownMenuItem(
                value: AdminPlaceStatusFilter.inactive,
                child: Text('Inativos'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                _updateFilters(filters.copyWith(status: value));
              }
            },
          ),
        ),
      ),
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Filtro: Modalidade',
        child: SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>(filters.sport ?? ''),
            initialValue: filters.sport ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Modalidade'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: '', child: Text('Todas')),
              DropdownMenuItem(value: 'futebol', child: Text('Futebol')),
              DropdownMenuItem(value: 'basquete', child: Text('Basquete')),
              DropdownMenuItem(value: 'volei', child: Text('Vôlei')),
              DropdownMenuItem(
                value: 'tenisDeMesa',
                child: Text('Tênis de mesa'),
              ),
              DropdownMenuItem(value: 'futsal', child: Text('Futsal')),
              DropdownMenuItem(value: 'corrida', child: Text('Corrida')),
              DropdownMenuItem(value: 'ciclismo', child: Text('Ciclismo')),
              DropdownMenuItem(value: 'caminhada', child: Text('Caminhada')),
            ],
            onChanged: (value) => _updateFilters(
              filters.copyWith(
                sport: value,
                clearSport: value == null || value.isEmpty,
              ),
            ),
          ),
        ),
      ),
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Filtro: Cidade exata',
        textField: true,
        child: SizedBox(
          width: 210,
          child: TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Cidade exata',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            onSubmitted: (value) => _updateFilters(
              filters.copyWith(cityLower: normalizeAdminSearch(value)),
            ),
          ),
        ),
      ),
      TextButton.icon(
        onPressed: () {
          _searchDebounce?.cancel();
          _searchController.clear();
          _cityController.clear();
          _updateFilters(const AdminPlacesFilters());
        },
        icon: const Icon(Icons.clear),
        label: const Text('Limpar filtros'),
      ),
    ],
  );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap});

  final AdminPlaceSummary place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = place.status == 'active';
    final pill = AdminStatusPill(
      label: active ? 'Ativo' : 'Inativo',
      tone: active ? AdminStatusTone.positive : AdminStatusTone.neutral,
    );
    // Em telas estreitas o estado vai junto das modalidades, sob o nome.
    final compact = MediaQuery.sizeOf(context).width < 600;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(place.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${place.city}, ${place.state}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (place.sports.isNotEmpty || compact) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (compact) pill,
                        ...place.sports.map(
                          (sport) => _SportTag(_sportLabel(sport)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!compact) ...<Widget>[const SizedBox(width: 16), pill],
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _sportLabel(String value) => switch (value) {
    'futebol' => 'Futebol',
    'basquete' => 'Basquete',
    'volei' => 'Vôlei',
    'tenisDeMesa' => 'Tênis de mesa',
    'futsal' => 'Futsal',
    'corrida' => 'Corrida',
    'ciclismo' => 'Ciclismo',
    'caminhada' => 'Caminhada',
    _ => value,
  };
}

class _SportTag extends StatelessWidget {
  const _SportTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Semantics(
      label: 'Carregando Locais Esportivos',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const LinearProgressIndicator(),
            for (var row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    bar(220, 14),
                    const SizedBox(height: 10),
                    bar(120, 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mensagem de estado vazio ou de falha, com a ação que resolve.
class _PlacesMessage extends StatelessWidget {
  const _PlacesMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _PlacesEmpty extends StatelessWidget {
  const _PlacesEmpty({required this.filters});

  final AdminPlacesFilters filters;

  @override
  Widget build(BuildContext context) {
    final unfiltered = filters == const AdminPlacesFilters();
    return _PlacesMessage(
      icon: Icons.search_off,
      message: unfiltered
          ? 'Nenhum Local Esportivo cadastrado.'
          : 'Nenhum local corresponde aos filtros.',
      action: unfiltered
          ? FilledButton.icon(
              onPressed: () => context.go('/places/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Cadastrar primeiro local'),
            )
          : null,
    );
  }
}

class _PlacesError extends StatelessWidget {
  const _PlacesError({
    required this.onRetry,
    this.message = 'Não foi possível carregar os locais.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => _PlacesMessage(
    icon: Icons.cloud_off_outlined,
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Tentar novamente'),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Erro ao atualizar. Tentar novamente'),
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => const Material(
    color: AdminColors.warningContainer,
    borderRadius: BorderRadius.all(Radius.circular(10)),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, color: AdminColors.onWarningContainer),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Exibindo dados em cache; conecte-se para ver atualizações.',
              style: TextStyle(color: AdminColors.onWarningContainer),
            ),
          ),
        ],
      ),
    ),
  );
}

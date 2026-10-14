import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text(
          'Locais Esportivos',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.go('/places/new'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Cadastrar local'),
          ),
        ),
        const SizedBox(height: 16),
        _buildFilters(state.filters),
        if (state.isFromCache) ...<Widget>[
          const SizedBox(height: 12),
          const _OfflineBanner(),
        ],
        const SizedBox(height: 12),
        if (state.isLoading && state.places.isEmpty)
          const _PlacesSkeleton()
        else if (state.error != null && state.places.isEmpty)
          _PlacesError(onRetry: _controller.retry)
        else if (state.places.isEmpty)
          _PlacesEmpty(filters: state.filters)
        else ...<Widget>[
          if (state.error != null) _InlineError(onRetry: _controller.retry),
          ...state.places.map(
            (place) => _PlaceTile(
              place: place,
              onTap: () =>
                  context.go('/places/${Uri.encodeComponent(place.id)}'),
            ),
          ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.hasMore && !state.isLoadingMore)
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: _controller.loadNextPage,
                child: const Text('Carregar mais locais'),
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
      OutlinedButton.icon(
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
    final active = place.status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          active ? Icons.place_outlined : Icons.location_off_outlined,
        ),
        title: Text(place.name),
        subtitle: Text(
          '${place.city}, ${place.state} · ${place.sports.map(_sportLabel).join(', ')}',
        ),
        trailing: Chip(label: Text(active ? 'Ativo' : 'Inativo')),
        isThreeLine: false,
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

class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando Locais Esportivos',
    child: Column(
      children: <Widget>[
        LinearProgressIndicator(),
        SizedBox(height: 16),
        ListTile(
          leading: CircleAvatar(),
          title: Text(' '),
          subtitle: Text(' '),
        ),
        ListTile(
          leading: CircleAvatar(),
          title: Text(' '),
          subtitle: Text(' '),
        ),
        ListTile(
          leading: CircleAvatar(),
          title: Text(' '),
          subtitle: Text(' '),
        ),
      ],
    ),
  );
}

class _PlacesEmpty extends StatelessWidget {
  const _PlacesEmpty({required this.filters});

  final AdminPlacesFilters filters;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: <Widget>[
        const Icon(Icons.search_off, size: 40),
        const SizedBox(height: 8),
        Text(
          filters == const AdminPlacesFilters()
              ? 'Nenhum Local Esportivo cadastrado.'
              : 'Nenhum local corresponde aos filtros.',
        ),
        if (filters == const AdminPlacesFilters()) ...<Widget>[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/places/new'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Cadastrar primeiro local'),
          ),
        ],
      ],
    ),
  );
}

class _PlacesError extends StatelessWidget {
  const _PlacesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 8),
          const Text('Não foi possível carregar os locais.'),
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
    color: Color(0xFFFFF3CD),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Exibindo dados em cache; conecte-se para ver atualizações.',
            ),
          ),
        ],
      ),
    ),
  );
}

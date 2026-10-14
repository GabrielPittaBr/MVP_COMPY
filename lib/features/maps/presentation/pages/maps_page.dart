import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../../shared/widgets/custom_sport_marker.dart';
import '../../../chat/presentation/widgets/share_place_sheet.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/usecases/filter_map_places.dart';
import '../providers/maps_providers.dart';
import '../widgets/place_details_sheet.dart';

class MapsPage extends ConsumerStatefulWidget {
  const MapsPage({this.initialPlaceId, super.key});

  final String? initialPlaceId;

  @override
  ConsumerState<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends ConsumerState<MapsPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String? _resolvingSelectedId;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(mapsSearchQueryProvider);
  }

  @override
  void didUpdateWidget(MapsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPlaceId != widget.initialPlaceId) {
      ref.read(selectedPlaceProvider.notifier).state = null;
      _clearDiscoveryFilters();
      final id = widget.initialPlaceId;
      if (id != null) ref.invalidate(placeByIdProvider(id));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearDiscoveryFilters() {
    _searchController.clear();
    ref.read(mapsSearchQueryProvider.notifier).state = '';
    ref.read(mapsSportFilterProvider.notifier).state = null;
  }

  void _selectPlace(SportPlace place) {
    ref.read(selectedPlaceProvider.notifier).state = place;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(place.coordinates, AppGeo.focusZoom);
    });
  }

  void _reconcileSelectedPlace(PlacesStreamResult snapshot) {
    if (snapshot.isFromCache) return;
    final selected = ref.read(selectedPlaceProvider);
    if (selected == null) return;

    SportPlace? current;
    for (final place in snapshot.places) {
      if (place.id == selected.id) {
        current = place;
        break;
      }
    }
    if (current != null) {
      if (current != selected) {
        ref.read(selectedPlaceProvider.notifier).state = current;
      }
      return;
    }
    if (selected.status == PlaceStatus.inactive ||
        _resolvingSelectedId == selected.id) {
      return;
    }

    // A consulta de ativos deixou de incluir a seleção. Feche as ações
    // imediatamente e atualize o contexto histórico pelo ID.
    final placeId = selected.id;
    ref.read(selectedPlaceProvider.notifier).state =
        selected.copyWithStatus(PlaceStatus.inactive);
    unawaited(_refreshSelectedPlace(placeId));
  }

  Future<void> _refreshSelectedPlace(String id) async {
    _resolvingSelectedId = id;
    ref.invalidate(placeByIdProvider(id));
    try {
      final result = await ref.read(placeByIdProvider(id).future);
      if (!mounted || ref.read(selectedPlaceProvider)?.id != id) return;
      ref.read(selectedPlaceProvider.notifier).state = result.place;
    } catch (_) {
      // Mantém a seleção provisoriamente inativa: falha de rede nunca reabre
      // as ações com um estado ativo desatualizado.
    } finally {
      if (_resolvingSelectedId == id) _resolvingSelectedId = null;
    }
  }

  void _retryPlaces() => ref.invalidate(placesProvider);

  void _retryDeepLink() {
    final id = widget.initialPlaceId;
    if (id != null) ref.invalidate(placeByIdProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);
    final searchQuery = ref.watch(mapsSearchQueryProvider);
    final sportFilter = ref.watch(mapsSportFilterProvider);
    final lookupAsync = widget.initialPlaceId == null
        ? null
        : ref.watch(placeByIdProvider(widget.initialPlaceId!));

    final deepLinkId = widget.initialPlaceId;
    if (deepLinkId != null) {
      ref.listen<AsyncValue<PlaceLookupResult>>(placeByIdProvider(deepLinkId),
          (previous, next) {
        next.whenData((lookup) {
          final place = lookup.place;
          if (place != null && widget.initialPlaceId == place.id) {
            _selectPlace(place);
          }
        });
      });
    }
    ref.listen<AsyncValue<PlacesStreamResult>>(placesProvider,
        (previous, next) {
      next.whenData(_reconcileSelectedPlace);
    });

    final places = placesAsync.valueOrNull?.places ?? const <SportPlace>[];
    final visiblePlaces = filterMapPlaces(
      places,
      query: searchQuery,
      sport: sportFilter,
    );

    return PopScope(
      canPop: selectedPlace == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(selectedPlaceProvider.notifier).state = null;
      },
      child: _buildScaffold(
        context,
        placesAsync,
        visiblePlaces,
        selectedPlace,
        lookupAsync,
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<PlacesStreamResult> placesAsync,
    List<SportPlace> visiblePlaces,
    SportPlace? selectedPlace,
    AsyncValue<PlaceLookupResult>? lookupAsync,
  ) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: AppGeo.taquaraCenter,
              initialZoom: AppGeo.defaultZoom,
              onTap: (_, __) =>
                  ref.read(selectedPlaceProvider.notifier).state = null,
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.com.compy.mvp',
              ),
              placesAsync.when(
                data: (_) => MarkerLayer(
                  markers: <Marker>[
                    for (final place in visiblePlaces)
                      Marker(
                        point: place.coordinates,
                        width: place.id == selectedPlace?.id ? 56 : 40,
                        height: place.id == selectedPlace?.id ? 70 : 50,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _selectPlace(place),
                          child: CustomSportMarker(
                            sport: place.primarySport,
                            selected: place.id == selectedPlace?.id,
                          ),
                        ),
                      ),
                  ],
                ),
                loading: () => const MarkerLayer(markers: <Marker>[]),
                error: (_, __) => const MarkerLayer(markers: <Marker>[]),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: <Widget>[
                  const _BackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(28),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(mapsSearchQueryProvider.notifier)
                            .state = value,
                        decoration: InputDecoration(
                          hintText: AppStrings.mapsSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Limpar busca',
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(mapsSearchQueryProvider.notifier)
                                        .state = '';
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              _SportFilterMenu(
                                selectedSport:
                                    ref.watch(mapsSportFilterProvider),
                                onSelected: (sport) => ref
                                    .read(mapsSportFilterProvider.notifier)
                                    .state = sport,
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 78,
            left: 20,
            right: 20,
            child: _buildNotices(
              placesAsync,
              visiblePlaces,
              lookupAsync,
              selectedPlace,
            ),
          ),
          if (selectedPlace != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: PlaceDetailsSheet(
                place: selectedPlace,
                onCreateEvent: () {
                  if (selectedPlace.status != PlaceStatus.active) return;
                  final placeId = selectedPlace.id;
                  ref.read(selectedPlaceProvider.notifier).state = null;
                  context.go(AppRoutes.create, extra: placeId);
                },
                onShare: () {
                  if (selectedPlace.status == PlaceStatus.active) {
                    SharePlaceSheet.show(context, selectedPlace.id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotices(
    AsyncValue<PlacesStreamResult> placesAsync,
    List<SportPlace> visiblePlaces,
    AsyncValue<PlaceLookupResult>? lookupAsync,
    SportPlace? selectedPlace,
  ) {
    final notices = <Widget>[];
    if (placesAsync.hasError) {
      notices.add(_MapNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Não foi possível carregar os locais.',
        actionLabel: 'Tentar novamente',
        onAction: _retryPlaces,
        isError: true,
      ));
    } else if (placesAsync.isLoading && !placesAsync.hasValue) {
      notices.add(const _MapNotice(
        icon: Icons.location_searching,
        message: 'Carregando locais esportivos…',
        isLoading: true,
      ));
    }

    final result = placesAsync.valueOrNull;
    if (result?.isFromCache == true) {
      notices.add(const _MapNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Exibindo locais salvos neste dispositivo (offline).',
      ));
    }
    if (result != null && visiblePlaces.isEmpty && !placesAsync.hasError) {
      final hasFilter = ref.read(mapsSearchQueryProvider).trim().isNotEmpty ||
          ref.read(mapsSportFilterProvider) != null;
      notices.add(_MapNotice(
        icon: Icons.location_off_outlined,
        message: hasFilter
            ? 'Nenhum local encontrado com estes filtros.'
            : 'Nenhum local ativo disponível no momento.',
        actionLabel: hasFilter ? 'Limpar busca e filtros' : null,
        onAction: hasFilter ? _clearDiscoveryFilters : null,
      ));
    }

    final deepLinkId = widget.initialPlaceId;
    if (deepLinkId != null && selectedPlace?.id != deepLinkId) {
      if (lookupAsync?.hasError == true) {
        notices.add(_MapNotice(
          icon: Icons.cloud_off_outlined,
          message: 'Não foi possível carregar o local. Verifique a conexão.',
          actionLabel: 'Tentar novamente',
          onAction: _retryDeepLink,
          isError: true,
        ));
      } else if (lookupAsync?.isLoading == true) {
        notices.add(const _MapNotice(
          icon: Icons.location_searching,
          message: 'Carregando local…',
          isLoading: true,
        ));
      } else {
        final lookup = lookupAsync?.valueOrNull;
        if (lookup != null && lookup.place == null) {
          notices.add(_MapNotice(
            icon: lookup.isFromCache
                ? Icons.cloud_off_outlined
                : Icons.location_off_outlined,
            message: lookup.isFromCache
                ? 'Não foi possível carregar o local offline.'
                : 'Local não encontrado.',
            actionLabel: lookup.isFromCache ? 'Tentar novamente' : null,
            onAction: lookup.isFromCache ? _retryDeepLink : null,
            isError: lookup.isFromCache,
          ));
        }
      }
    }

    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: notices
          .map((notice) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: notice,
              ))
          .toList(growable: false),
    );
  }
}

class _SportFilterMenu extends StatelessWidget {
  const _SportFilterMenu(
      {required this.selectedSport, required this.onSelected});

  final Sport? selectedSport;
  final ValueChanged<Sport?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Filtrar por modalidade',
      icon: Icon(
        Icons.tune,
        color: selectedSport == null ? null : AppColors.primary,
      ),
      onSelected: (choice) => onSelected(choice is Sport ? choice : null),
      itemBuilder: (context) => <PopupMenuEntry<Object>>[
        const PopupMenuItem<Object>(
            value: _AllSportsChoice.value, child: Text('Todas as modalidades')),
        for (final sport in Sport.values)
          PopupMenuItem<Object>(value: sport, child: Text(sport.label)),
      ],
    );
  }
}

enum _AllSportsChoice { value }

class _MapNotice extends StatelessWidget {
  const _MapNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.onSurface;
    return Material(
      elevation: 3,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            if (isLoading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color))),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends ConsumerWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 4,
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (ref.read(selectedPlaceProvider) != null) {
            ref.read(selectedPlaceProvider.notifier).state = null;
            return;
          }
          context.canPop() ? context.pop() : context.go(AppRoutes.home);
        },
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.arrow_back),
        ),
      ),
    );
  }
}

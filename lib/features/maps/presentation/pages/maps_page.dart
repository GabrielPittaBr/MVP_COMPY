import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/maps_providers.dart';
import '../widgets/custom_sport_marker.dart';
import '../widgets/place_details_sheet.dart';

/// Tela de mapa (RF04): exibe pins customizados para os locais
/// esportivos cadastrados em Taquara/RS. Tocar num pin abre um bottom
/// sheet com detalhes do local.
class MapsPage extends ConsumerStatefulWidget {
  const MapsPage({super.key});

  @override
  ConsumerState<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends ConsumerState<MapsPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: AppGeo.taquaraCenter,
              initialZoom: AppGeo.defaultZoom,
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.com.compy.mvp',
              ),
              placesAsync.when(
                data: (places) => MarkerLayer(
                  markers: <Marker>[
                    for (final place in places)
                      Marker(
                        point: place.coordinates,
                        width: place.id == selectedPlace?.id ? 56 : 40,
                        height: place.id == selectedPlace?.id ? 70 : 50,
                        // Pin em forma de gota: o widget fica acima do
                        // ponto para a ponta tocar a coordenada exata.
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedPlaceProvider.notifier).state = place;
                            _mapController.move(
                              place.coordinates,
                              AppGeo.focusZoom,
                            );
                          },
                          child: CustomSportMarker(
                            // Locais aceitam vários esportes; o pin usa a
                            // modalidade principal do local.
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

          // Barra de busca flutuante (mockup "2 / 2.1 Pesquisa de pontos")
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(28),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppStrings.mapsSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
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
          ),

          // Bottom sheet de detalhes — surge quando há pin selecionado.
          if (selectedPlace != null)
            PlaceDetailsSheet(
              place: selectedPlace,
              onCreateEvent: () {
                ref.read(selectedPlaceProvider.notifier).state = null;
                // TODO: levar ao create_event com place pré-preenchido.
              },
              onShare: () {},
              onFavorite: () {},
            ),
        ],
      ),
    );
  }
}

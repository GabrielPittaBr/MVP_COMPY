import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../../shared/widgets/custom_sport_marker.dart';
import '../../../chat/presentation/widgets/share_place_sheet.dart';
import '../providers/maps_providers.dart';
import '../widgets/place_details_sheet.dart';

/// Tela de mapa (RF04): exibe pins customizados para os locais
/// esportivos cadastrados em Taquara/RS. Tocar num pin abre um bottom
/// sheet com detalhes do local.
class MapsPage extends ConsumerStatefulWidget {
  const MapsPage({this.initialPlaceId, super.key});

  /// Local a abrir já selecionado — é assim que o card de local encaminhado
  /// no chat traz o usuário de volta ao pin. Mesmo padrão do
  /// `initialPlaceId` da criação de evento: viaja o id, não o objeto.
  final String? initialPlaceId;

  @override
  ConsumerState<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends ConsumerState<MapsPage> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _focusInitialPlace();
  }

  @override
  void didUpdateWidget(MapsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chegar aqui pelo card de local no chat nem sempre constrói a tela do
    // zero: se o mapa já estiver na pilha da aba Início, o GoRouter reaproveita
    // o elemento e só o `initialPlaceId` muda — o `initState` não roda de novo.
    if (oldWidget.initialPlaceId != widget.initialPlaceId) {
      _focusInitialPlace();
    }
  }

  void _focusInitialPlace() {
    final place = widget.initialPlaceId == null
        ? null
        : SportPlace.byId(widget.initialPlaceId!);
    if (place == null) return;
    // Depois do quadro: `selectedPlaceProvider` não pode ser escrito durante
    // a construção da árvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedPlaceProvider.notifier).state = place;
      _mapController.move(place.coordinates, AppGeo.focusZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);

    // O card do local vive dentro do Stack, não no back-stack: sem isso o
    // voltar do Android sairia do mapa com o card aberto na frente.
    return PopScope(
      canPop: selectedPlace == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(selectedPlaceProvider.notifier).state = null;
      },
      child: _buildScaffold(context, placesAsync, selectedPlace),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<List<SportPlace>> placesAsync,
    SportPlace? selectedPlace,
  ) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: AppGeo.taquaraCenter,
              initialZoom: AppGeo.defaultZoom,
              // Tocar no mapa fora do card desfaz a seleção. A câmera
              // fica onde está: mover sozinha depois de um toque solto
              // desorienta mais do que ajuda.
              onTap: (_, __) =>
                  ref.read(selectedPlaceProvider.notifier).state = null,
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
          // com o botão de voltar ao lado — o mapa é full-bleed, uma
          // AppBar cobriria o mapa e destoaria do mockup.
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
                ],
              ),
            ),
          ),

          // Bottom sheet de detalhes — surge quando há pin selecionado.
          // O Align é o par obrigatório do `expand: false` do sheet: sem
          // ele o card iria para o topo do Stack.
          if (selectedPlace != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: PlaceDetailsSheet(
                place: selectedPlace,
                // Vai para o formulário com o local já escolhido. Viaja
                // o id (estável no catálogo), não o objeto.
                onCreateEvent: () {
                  final placeId = selectedPlace.id;
                  ref.read(selectedPlaceProvider.notifier).state = null;
                  context.go(AppRoutes.create, extra: placeId);
                },
                // O card segue aberto atrás do seletor: quem desiste de
                // compartilhar volta para o local onde estava.
                onShare: () => SharePlaceSheet.show(context, selectedPlace.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botão flutuante de voltar, à esquerda da barra de busca. Mesma
/// elevação do campo para os dois lerem como um par.
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
        // Mesma regra do voltar do Android (PopScope acima): com um local
        // aberto, o primeiro voltar fecha o card; o segundo sai do mapa.
        // A Home entra no mapa com `go`, que empilha /home/maps sobre
        // /home — o pop volta para a Home com o bottom nav intacto. O
        // fallback cobre quem chega direto por deep link.
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

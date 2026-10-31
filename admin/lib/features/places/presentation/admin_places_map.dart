import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/admin_colors.dart';
import '../data/admin_place_model.dart';
import 'admin_osm_map.dart';

const Color _activePinColor = AdminColors.primary;
// Mesmo cinza da borda dos componentes: 3:1 sobre os tiles claros.
const Color _inactivePinColor = AdminColors.outline;
const double _pinSize = 44;
const double _labelHeight = 40;
const double _labelMaxWidth = 220;
const double _emptyZoom = 13;

/// Altura do mapa geral: generosa, para a captura de tela sair legível.
double adminPlacesMapHeight(BuildContext context) =>
    math.max(480, MediaQuery.sizeOf(context).height * 0.7);

/// Mapa geral dos Locais Esportivos, com um pin por local recebido.
///
/// [showNames] fica com quem usa o mapa: ele é recriado a cada troca de
/// filtro, e a escolha não pode se perder no meio da captura.
class AdminPlacesMap extends StatefulWidget {
  const AdminPlacesMap({
    required this.places,
    required this.showNames,
    required this.onShowNamesChanged,
    required this.onOpenPlace,
    this.tileLayer,
    super.key,
  });

  final List<AdminPlaceRecord> places;
  final bool showNames;
  final ValueChanged<bool> onShowNamesChanged;
  final ValueChanged<String> onOpenPlace;
  // Os testes trocam os tiles do OpenStreetMap por uma camada sem rede.
  final Widget? tileLayer;

  @override
  State<AdminPlacesMap> createState() => _AdminPlacesMapState();
}

class _AdminPlacesMapState extends State<AdminPlacesMap> {
  String? _selectedId;

  @override
  void didUpdateWidget(covariant AdminPlacesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.places.every((place) => place.id != _selectedId)) {
      _selectedId = null;
    }
  }

  // O mapa já nasce enquadrado nos pins. Mover a câmera por código
  // (`initialCameraFit`, `fitCamera`, `move`) no flutter_map 7.0.2 deixa os
  // tiles do novo zoom invisíveis até o primeiro gesto no mapa.
  MapCamera _framedCamera(Size size) {
    final camera = MapCamera.initialCamera(
      const MapOptions(
        initialCenter: adminTaquaraCenter,
        initialZoom: _emptyZoom,
      ),
    ).withNonRotatedSize(math.Point<double>(size.width, size.height));
    if (widget.places.isEmpty) return camera;
    return CameraFit.coordinates(
      coordinates: <LatLng>[for (final place in widget.places) _point(place)],
      // Folga no topo para o nome acima do pin mais ao norte.
      padding: const EdgeInsets.fromLTRB(
        48,
        _pinSize + _labelHeight + 16,
        48,
        32,
      ),
      maxZoom: 16,
      // Zoom inteiro: os tiles saem na resolução nativa, nítidos na captura.
      forceIntegerZoomLevel: true,
    ).fit(camera);
  }

  void _togglePin(String id) =>
      setState(() => _selectedId = _selectedId == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final count = widget.places.length;
    // O pin selecionado vem por último para o nome dele ficar por cima.
    final ordered = <AdminPlaceRecord>[
      ...widget.places.where((place) => place.id != _selectedId),
      ...widget.places.where((place) => place.id == _selectedId),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(switch (count) {
              0 => 'Nenhum local para exibir no mapa.',
              1 => '1 local no mapa',
              _ => '$count locais no mapa',
            }, style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const _LegendItem(color: _activePinColor, label: 'Ativo'),
                const _LegendItem(color: _inactivePinColor, label: 'Inativo'),
                FilterChip(
                  label: const Text('Mostrar nomes'),
                  selected: widget.showNames,
                  onSelected: widget.onShowNamesChanged,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: adminPlacesMapHeight(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final camera = _framedCamera(constraints.biggest);
                return Stack(
                  children: <Widget>[
                    FlutterMap(
                      // Pontos novos recriam o mapa já enquadrado neles; mudanças
                      // só de nome mantêm o zoom ajustado para a captura.
                      key: ValueKey<String>(_locationsKey(widget.places)),
                      options: MapOptions(
                        initialCenter: camera.center,
                        initialZoom: camera.zoom,
                        onTap: (_, _) {
                          if (_selectedId != null) {
                            setState(() => _selectedId = null);
                          }
                        },
                      ),
                      children: <Widget>[
                        widget.tileLayer ?? adminOsmTileLayer(),
                        MarkerLayer(
                          markers: <Marker>[
                            for (final place in ordered)
                              Marker(
                                key: ValueKey<String>('place-pin-${place.id}'),
                                point: _point(place),
                                width: _labelMaxWidth,
                                height: _pinSize + _labelHeight,
                                // A ponta do pin fica no ponto; o nome, acima dele.
                                alignment: Alignment.topCenter,
                                child: _PlacePin(
                                  place: place,
                                  showName:
                                      widget.showNames ||
                                      place.id == _selectedId,
                                  onTapPin: () => _togglePin(place.id),
                                  onOpen: () => widget.onOpenPlace(place.id),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const AdminOsmAttribution(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacePin extends StatelessWidget {
  const _PlacePin({
    required this.place,
    required this.showName,
    required this.onTapPin,
    required this.onOpen,
  });

  final AdminPlaceRecord place;
  final bool showName;
  final VoidCallback onTapPin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pin = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTapPin,
        child: Semantics(
          button: true,
          label: place.isActive ? place.name : '${place.name} (inativo)',
          child: Icon(
            Icons.location_pin,
            size: _pinSize,
            color: place.isActive ? _activePinColor : _inactivePinColor,
            shadows: const <Shadow>[
              Shadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (showName) _PinLabel(name: place.name, onTap: onOpen),
        if (showName) pin else Tooltip(message: place.name, child: pin),
      ],
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(8));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: 'Abrir local',
        child: Material(
          color: AdminColors.surface,
          elevation: 2,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AdminColors.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(Icons.location_pin, size: 20, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

LatLng _point(AdminPlaceRecord place) =>
    LatLng(place.coordinates.latitude, place.coordinates.longitude);

String _locationsKey(List<AdminPlaceRecord> places) => places
    .map(
      (place) =>
          '${place.id}@${place.coordinates.latitude},'
          '${place.coordinates.longitude}',
    )
    .join('|');

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Constantes geográficas relativas a Taquara/RS (RN-01: delimitação geográfica).
abstract final class AppGeo {
  /// Centro aproximado de Taquara/RS — usado como ponto inicial do mapa.
  static const LatLng taquaraCenter = LatLng(-29.6500, -50.7800);

  /// Zoom inicial confortável para visualizar o município.
  static const double defaultZoom = 14.0;

  /// Zoom usado ao focar em um pin específico.
  static const double focusZoom = 16.5;

  /// Centro navegável: cerca de 30 km em cada direção de Taquara.
  /// O retângulo inclui o Parque do Trabalhador e os municípios próximos.
  static final LatLngBounds explorationBounds = LatLngBounds(
    const LatLng(-29.92, -51.09),
    const LatLng(-29.38, -50.47),
  );

  /// Zoom regional mínimo e detalhe máximo de ruas/quadras na aba Explorar.
  static const double explorationMinZoom = 11.5;
  static const double explorationMaxZoom = 19.0;

  /// Raio (km) da busca de "Eventos Próximos" na Home (RF03).
  static const double nearbyRadiusKm = 10.0;
}

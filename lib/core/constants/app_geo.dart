import 'package:latlong2/latlong.dart';

/// Constantes geográficas relativas a Taquara/RS (RN-01: delimitação geográfica).
abstract final class AppGeo {
  /// Centro aproximado de Taquara/RS — usado como ponto inicial do mapa.
  static const LatLng taquaraCenter = LatLng(-29.6500, -50.7800);

  /// Zoom inicial confortável para visualizar o município.
  static const double defaultZoom = 14.0;

  /// Zoom usado ao focar em um pin específico.
  static const double focusZoom = 16.5;
}

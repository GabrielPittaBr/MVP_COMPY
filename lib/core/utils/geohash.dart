import 'dart:math' as math;

/// Codificação Geohash (base32) usada para consultas geográficas no
/// Firestore sem dependência de pacotes externos (estilo GeoFlutterFire).
///
/// Estratégia: cada evento grava um campo `geohash` (precisão 9). Para
/// buscar por raio, calculamos a célula central + 8 vizinhas na precisão
/// adequada ao raio e fazemos uma range query (`startAt`/`endAt`) por
/// célula; o refinamento fino (distância exata) é feito no cliente.
abstract final class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Precisão padrão gravada nos documentos.
  static const int storagePrecision = 9;

  /// Codifica [lat]/[lng] em um geohash com [precision] caracteres.
  static String encode(double lat, double lng, {int precision = storagePrecision}) {
    var idx = 0;
    var bit = 0;
    var evenBit = true;
    final buffer = StringBuffer();
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;

    while (buffer.length < precision) {
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          idx = idx * 2 + 1;
          lngMin = mid;
        } else {
          idx = idx * 2;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          idx = idx * 2 + 1;
          latMin = mid;
        } else {
          idx = idx * 2;
          latMax = mid;
        }
      }
      evenBit = !evenBit;
      if (++bit == 5) {
        buffer.write(_base32[idx]);
        bit = 0;
        idx = 0;
      }
    }
    return buffer.toString();
  }

  /// Menor precisão cuja célula ainda cobre o [radiusKm] (tabela padrão
  /// de dimensões de célula geohash, como no GeoFlutterFire).
  static int precisionForRadius(double radiusKm) {
    if (radiusKm <= 0.00477) return 9;
    if (radiusKm <= 0.0382) return 8;
    if (radiusKm <= 0.153) return 7;
    if (radiusKm <= 1.22) return 6;
    if (radiusKm <= 4.89) return 5;
    if (radiusKm <= 39.1) return 4;
    if (radiusKm <= 156.5) return 3;
    if (radiusKm <= 1252.3) return 2;
    return 1;
  }

  /// Largura (graus de longitude) de uma célula na [precision].
  static double _cellWidthDeg(int precision) =>
      360 / math.pow(2, (5 * precision + 1) ~/ 2);

  /// Altura (graus de latitude) de uma célula na [precision].
  static double _cellHeightDeg(int precision) =>
      180 / math.pow(2, (5 * precision) ~/ 2);

  /// Células (central + até 8 vizinhas) que cobrem o círculo de raio
  /// [radiusKm] centrado em [lat]/[lng]. Deduplica células repetidas
  /// (ocorre perto dos polos ou com raios pequenos).
  static Set<String> coveringCells(double lat, double lng, double radiusKm) {
    final precision = precisionForRadius(radiusKm);
    final dLat = _cellHeightDeg(precision);
    final dLng = _cellWidthDeg(precision);

    final cells = <String>{};
    for (final offLat in <double>[-dLat, 0, dLat]) {
      for (final offLng in <double>[-dLng, 0, dLng]) {
        final nLat = (lat + offLat).clamp(-90.0, 90.0);
        var nLng = lng + offLng;
        if (nLng > 180) nLng -= 360;
        if (nLng < -180) nLng += 360;
        cells.add(encode(nLat, nLng, precision: precision));
      }
    }
    return cells;
  }
}

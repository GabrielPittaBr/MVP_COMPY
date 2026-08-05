import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_geo.dart';

/// Posição atual do usuário, com pedido de permissão ao device.
///
/// Nunca lança: se o serviço estiver desligado ou a permissão for negada,
/// devolve o centro de Taquara ([AppGeo.taquaraCenter]) para que a Home
/// continue funcional (RN-01: o app é delimitado a Taquara de qualquer
/// forma). Use `ref.invalidate(userPositionProvider)` para reconsultar.
final userPositionProvider = FutureProvider<LatLng>((ref) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return AppGeo.taquaraCenter;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return AppGeo.taquaraCenter;
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    // Timeout/erro do GPS: tenta a última posição conhecida.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    return AppGeo.taquaraCenter;
  }
});

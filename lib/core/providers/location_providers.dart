import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_geo.dart';

/// Posição atual do usuário, com pedido de permissão ao device.
///
/// **Nunca lança.** Serviço desligado, permissão negada, GPS mudo ou até o
/// plugin indisponível na plataforma — tudo cai no centro de Taquara
/// ([AppGeo.taquaraCenter]), porque o app é delimitado a Taquara de
/// qualquer forma (RN-01) e nenhuma dessas situações é motivo para a Home
/// inteira virar uma tela de erro.
///
/// O `try` cobre a função toda de propósito: as chamadas de permissão do
/// geolocator também lançam (`PermissionDefinitionsNotFoundException`,
/// `PermissionRequestInProgressException`, `MissingPluginException`), e
/// antes elas passavam por fora do tratamento e vazavam para quem
/// observasse este provider.
///
/// Use `ref.invalidate(userPositionProvider)` para reconsultar.
final userPositionProvider = FutureProvider<LatLng>((ref) async {
  try {
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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    // Timeout/erro do GPS: tenta a última posição conhecida antes de
    // desistir para o centro do município.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
    } catch (_) {
      // Plugin indisponível — segue para o fallback.
    }
    return AppGeo.taquaraCenter;
  }
});

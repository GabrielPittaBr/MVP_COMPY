import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_geo.dart';

/// Situação da permissão de localização do aparelho.
enum LocationAccess {
  /// Permitida e com o GPS ligado.
  granted,

  /// Ainda não pedida, ou negada uma vez: o app pode pedir de novo.
  notGranted,

  /// Negada para sempre: só as configurações do Android desfazem.
  deniedForever,

  /// Permitida, mas com o serviço de localização desligado.
  serviceOff,
}

/// Lê a permissão **sem pedir** (chore/lgpd). O pedido só acontece depois do
/// aviso em destaque que a Play exige e que explica que a posição não sai do
/// aparelho — ver `lib/shared/widgets/location_disclosure.dart`. Antes, a Home
/// abria direto o diálogo do Android na primeira vez.
final locationAccessProvider = FutureProvider<LocationAccess>((ref) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return LocationAccess.notGranted;
    }
    return await Geolocator.isLocationServiceEnabled()
        ? LocationAccess.granted
        : LocationAccess.serviceOff;
  } catch (_) {
    // Plugin indisponível na plataforma: para o app é o mesmo que não ter.
    return LocationAccess.notGranted;
  }
});

/// Posição atual do usuário, **só se ele já permitiu**.
///
/// **Nunca lança.** Sem permissão, serviço desligado, GPS mudo ou até o
/// plugin indisponível na plataforma — tudo cai no centro de Taquara
/// ([AppGeo.taquaraCenter]), porque o app é delimitado a Taquara de
/// qualquer forma (RN-01) e nenhuma dessas situações é motivo para a Home
/// inteira virar uma tela de erro.
///
/// A posição é usada só no aparelho, para ordenar eventos por distância:
/// nunca é gravada nem enviada ao servidor (Política de Privacidade, seção 2).
///
/// Use `ref.invalidate(userPositionProvider)` para reconsultar.
final userPositionProvider = FutureProvider<LatLng>((ref) async {
  final access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) return AppGeo.taquaraCenter;
  try {
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

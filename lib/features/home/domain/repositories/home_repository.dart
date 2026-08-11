import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport.dart';
import '../entities/sport_category.dart';

/// Contrato de dados da Home.
///
/// Stream para que ligações com Firestore sejam plug-and-play
/// (RNF02: tempo real); listas de categorias são síncronas.
abstract interface class HomeRepository {
  /// Categorias do carrossel da Home. Com [favoriteSports] preenchido o
  /// carrossel reflete o perfil do usuário; vazio cai no trio padrão.
  List<SportCategory> getCategories({List<Sport> favoriteSports});

  /// Eventos dentro de [radiusKm] a partir de [center], ordenados por
  /// distância crescente (RF03 — proximidade real).
  Stream<List<Event>> watchNearbyEvents(
    LatLng center, {
    double radiusKm = AppGeo.nearbyRadiusKm,
  });
}

import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport.dart';
import '../entities/sport_category.dart';

/// Contrato de dados da Home.
///
/// Os eventos vêm de uma leitura pontual (a Home atualiza ao puxar para
/// baixo); listas de categorias são síncronas.
abstract interface class HomeRepository {
  /// Categorias do carrossel da Home. Com [favoriteSports] preenchido o
  /// carrossel reflete o perfil do usuário; vazio cai no trio padrão.
  List<SportCategory> getCategories({List<Sport> favoriteSports});

  /// Eventos dentro de [radiusKm] a partir de [center], ordenados por
  /// distância crescente (RF03 — proximidade real).
  Future<List<Event>> fetchNearbyEvents(
    LatLng center, {
    double radiusKm = AppGeo.nearbyRadiusKm,
  });
}

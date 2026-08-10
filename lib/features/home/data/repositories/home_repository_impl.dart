import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/constants/app_geo.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport.dart';
import '../../domain/entities/sport_category.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';
// Mocks desligados — a Home agora consome o Firestore real com
// geolocalização. Mantido apenas como referência de fixtures.
// import '../datasources/mock_events.dart';

/// Implementação que decide a fonte de dados (Firebase ou vazio) com base
/// na flag global [kUseFirebaseRepos].
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote);
  final HomeRemoteDataSource? _remote;

  static const Distance _distance = Distance();

  /// Trio exibido enquanto não há favoritos do usuário.
  static const List<Sport> _defaultCategorySports = <Sport>[
    Sport.futebol,
    Sport.basquete,
    Sport.volei,
  ];

  @override
  List<SportCategory> getCategories({
    List<Sport> favoriteSports = const <Sport>[],
  }) {
    // O carrossel mostra um punhado de modalidades; as demais ficam no
    // "Ver mais" (folha de filtros). Quando a tarefa 13 entregar os
    // esportes favoritos editáveis, basta o provider repassar a lista do
    // perfil aqui — a Home passa a refletir o usuário sem mais mudanças.
    final sports =
        favoriteSports.isNotEmpty ? favoriteSports : _defaultCategorySports;
    return <SportCategory>[
      for (final sport in sports)
        SportCategory(sport: sport, imageUrl: sport.banner),
    ];
  }

  @override
  Stream<List<Event>> watchNearbyEvents(
    LatLng center, {
    double radiusKm = AppGeo.nearbyRadiusKm,
  }) {
    if (!kUseFirebaseRepos || _remote == null) {
      // return Stream<List<Event>>.value(MockEvents.nearby);
      return Stream<List<Event>>.value(const <Event>[]);
    }

    return _remote
        .watchNearbyEvents(center: center, radiusKm: radiusKm)
        .map((docs) {
      // As células geohash cobrem uma área maior que o círculo pedido —
      // refinamos pela distância exata e ordenamos por proximidade.
      final events = <({Event event, double km})>[];
      for (final doc in docs) {
        final event = Event.fromMap(doc.id, doc.data());
        final km = _distance.as(
          LengthUnit.Kilometer,
          center,
          event.coordinates,
        );
        if (km <= radiusKm) events.add((event: event, km: km));
      }
      events.sort((a, b) => a.km.compareTo(b.km));
      return <Event>[for (final e in events) e.event];
    });
  }
}

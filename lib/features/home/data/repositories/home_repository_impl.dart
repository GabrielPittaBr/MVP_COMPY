import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_assets.dart';
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

  @override
  List<SportCategory> getCategories() {
    return <SportCategory>[
      const SportCategory(
        sport: Sport.futebol,
        imageUrl: AppAssets.soccerBanner,
      ),
      const SportCategory(
        sport: Sport.basquete,
        imageUrl: AppAssets.basketballBanner,
      ),
      const SportCategory(
        sport: Sport.volei,
        imageUrl: AppAssets.volleyballBanner,
      ),
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

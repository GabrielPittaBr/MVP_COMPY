import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport.dart';
import '../../domain/entities/sport_category.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';
import '../datasources/mock_events.dart';

/// Implementação que decide a fonte de dados (Firebase ou mock) com base
/// na flag global [kUseFirebaseRepos].
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote);
  final HomeRemoteDataSource? _remote;

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
  Stream<List<Event>> watchNearbyEvents() {
    if (!kUseFirebaseRepos || _remote == null) {
      return Stream<List<Event>>.value(MockEvents.nearby);
    }

    return _remote.watchNearbyEvents().map((snapshot) {
      return snapshot.docs
          .map((doc) => Event.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}

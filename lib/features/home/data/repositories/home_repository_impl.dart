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
  // ignore: unused_field
  final HomeRemoteDataSource _remote;

  @override
  List<SportCategory> getCategories() {
    return <SportCategory>[
      const SportCategory(sport: Sport.futebol, imageUrl: AppAssets.soccerBanner),
      const SportCategory(sport: Sport.basquete, imageUrl: AppAssets.basketballBanner),
      const SportCategory(sport: Sport.volei, imageUrl: AppAssets.volleyballBanner),
    ];
  }

  @override
  Stream<List<Event>> watchNearbyEvents() {
    if (!kUseFirebaseRepos) {
      // Em modo mock devolvemos apenas um snapshot único;
      // basta para popular a UI sem complicar com timers.
      return Stream<List<Event>>.value(MockEvents.nearby);
    }
    // TODO(integração): mapear QuerySnapshot -> List<Event> via EventModel.
    return const Stream<List<Event>>.empty();
  }
}

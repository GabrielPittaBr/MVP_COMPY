import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
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
      return snapshot.docs.map((doc) => _mapToEvent(doc)).toList();
    });
  }

  Event _mapToEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final geoPoint = data['coordinates'] as GeoPoint;
    final timestamp = data['dateTime'] as Timestamp;

    return Event(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.futebol,
      ),
      location: (data['location'] as String?) ?? '',
      coordinates: LatLng(geoPoint.latitude, geoPoint.longitude),
      dateTime: timestamp.toDate(),
      skillLevel: SkillLevel.values.firstWhere(
        (l) => l.name == data['skillLevel'],
        orElse: () => SkillLevel.iniciante,
      ),
      totalSpots: (data['totalSpots'] as int?) ?? 0,
      remainingSpots: (data['remainingSpots'] as int?) ?? 0,
      bannerUrl: (data['bannerUrl'] as String?) ?? '',
      creator: _mapToUserSummary(data['creator']),
      description: (data['description'] as String?) ?? '',
      participants: (data['participants'] as List? ?? [])
          .map((p) => _mapToUserSummary(p))
          .toList(),
    );
  }

  UserSummary _mapToUserSummary(dynamic data) {
    if (data is! Map) {
      return const UserSummary(
        id: 'unknown',
        name: 'Desconhecido',
        handle: '@unknown',
        avatarUrl: '',
      );
    }
    return UserSummary(
      id: (data['id'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      handle: (data['handle'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_geo.dart';
import 'package:mvp_compy/core/providers/location_providers.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/home/data/repositories/home_repository_impl.dart';
import 'package:mvp_compy/features/home/presentation/providers/home_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';

/// Conta quantas vezes a consulta geográfica foi aberta.
class _CountingHomeRepository extends HomeRepositoryImpl {
  _CountingHomeRepository() : super(null);

  int subscriptions = 0;

  @override
  Stream<List<Event>> watchNearbyEvents(
    LatLng center, {
    double radiusKm = AppGeo.nearbyRadiusKm,
  }) {
    subscriptions++;
    return Stream<List<Event>>.value(const <Event>[]);
  }
}

AuthUser _user(String uid) => AuthUser(
      uid: uid,
      email: '$uid@compy.test',
      displayName: uid,
      hasUsername: true,
      hasFavoriteSports: true,
    );

void main() {
  test('refaz a consulta de eventos próximos quando o usuário troca', () async {
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    final repository = _CountingHomeRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        authStateProvider.overrideWith((_) => auth.stream),
        userPositionProvider.overrideWith((_) async => AppGeo.taquaraCenter),
        homeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(nearbyEventsProvider, (_, __) {});

    auth.add(_user('ana'));
    await container.read(nearbyEventsProvider.future);
    final afterLogin = repository.subscriptions;

    // Logout seguido de outro login, sem reiniciar o app.
    auth.add(null);
    await Future<void>.delayed(Duration.zero);
    auth.add(_user('bia'));
    await Future<void>.delayed(Duration.zero);
    await container.read(nearbyEventsProvider.future);

    expect(repository.subscriptions, greaterThan(afterLogin));
  });
}

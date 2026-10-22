import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../data/datasources/ratings_remote_datasource.dart';
import '../../data/repositories/ratings_repository_impl.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../../domain/usecases/submit_event_ratings.dart';

final ratingsRemoteDataSourceProvider = Provider<RatingsRemoteDataSource?>(
  (ref) => kUseFirebaseRepos
      ? RatingsRemoteDataSource(
          FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        )
      : null,
);

final ratingsRepositoryProvider = Provider<RatingsRepository>(
  (ref) => RatingsRepositoryImpl(
    ref.watch(ratingsRemoteDataSourceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final submitEventRatingsProvider = Provider<SubmitEventRatings>(
  (ref) => SubmitEventRatings(ref.watch(ratingsRepositoryProvider)),
);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/services/firebase_service.dart';
import '../../data/datasources/ratings_remote_datasource.dart';
import '../../data/repositories/ratings_repository_impl.dart';
import '../../domain/entities/rating_summary.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../../domain/usecases/submit_event_ratings.dart';
import '../../domain/usecases/watch_rating_summary.dart';

/// Firebase só quando ele de fato subiu (`firebaseEnabled`): sem ele — no
/// fallback do `main` ou num teste de widget — a feature cai no mock, como
/// manda o AGENTS.md.
final ratingsRemoteDataSourceProvider = Provider<RatingsRemoteDataSource?>(
  (ref) => firebaseEnabled
      ? RatingsRemoteDataSource(
          FirebaseFunctions.instanceFor(region: kFunctionsRegion),
          FirebaseFirestore.instance,
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

final watchRatingSummaryProvider = Provider<WatchRatingSummary>(
  (ref) => WatchRatingSummary(ref.watch(ratingsRepositoryProvider)),
);

/// Média em tempo real de um alvo: perfil, Local Esportivo ou evento.
final ratingSummaryProvider =
    StreamProvider.family<RatingSummary, RatingTarget>((ref, target) {
  return ref.watch(watchRatingSummaryProvider).call(target);
});

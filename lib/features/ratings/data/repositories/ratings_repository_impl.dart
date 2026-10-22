import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/app_flags.dart';
import '../../domain/entities/event_rating_submission.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../datasources/in_memory_ratings_store.dart';
import '../datasources/ratings_remote_datasource.dart';

class RatingsRepositoryImpl implements RatingsRepository {
  RatingsRepositoryImpl(this._remote,
      {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  final RatingsRemoteDataSource? _remote;
  final DateTime Function() _clock;

  @override
  Future<void> submit(EventRatingSubmission submission) async {
    if (!kUseFirebaseRepos || _remote == null) {
      InMemoryRatingsStore.instance.submit(submission, now: _clock());
      return;
    }
    try {
      await _remote.submit(submission.toPayload());
    } on FirebaseFunctionsException catch (error) {
      throw switch (error.code) {
        'already-exists' => const RatingAlreadySubmittedException(),
        'failed-precondition' => const RatingEventNotEndedException(),
        'permission-denied' => const RatingNotParticipantException(),
        'unavailable' => const RatingOfflineException(),
        _ => RatingSubmitException(error),
      };
    }
  }
}

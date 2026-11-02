import '../entities/rating_summary.dart';
import '../repositories/ratings_repository.dart';

class WatchRatingSummary {
  const WatchRatingSummary(this._repository);
  final RatingsRepository _repository;

  Stream<RatingSummary> call(RatingTarget target) =>
      _repository.watchSummary(target);
}

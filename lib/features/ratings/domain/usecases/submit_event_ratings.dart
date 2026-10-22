import '../entities/event_rating_submission.dart';
import '../repositories/ratings_repository.dart';

class SubmitEventRatings {
  const SubmitEventRatings(this._repository);
  final RatingsRepository _repository;

  Future<void> call(EventRatingSubmission submission) =>
      _repository.submit(submission);
}

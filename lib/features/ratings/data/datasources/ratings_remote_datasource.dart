import 'package:cloud_functions/cloud_functions.dart';

/// Chama a callable `submitEventRatings` (functions/src/event_ratings.ts).
class RatingsRemoteDataSource {
  RatingsRemoteDataSource(this._functions);
  final FirebaseFunctions _functions;

  Future<void> submit(Map<String, Object?> payload) async {
    await _functions.httpsCallable('submitEventRatings').call<Object?>(payload);
  }
}

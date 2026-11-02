import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/rating_summary.dart';

/// Avaliações no Firebase: a callable `submitEventRatings` grava, e os
/// agregados de `ratingSummaries/{tipo}_{id}` são só leitura.
class RatingsRemoteDataSource {
  RatingsRemoteDataSource(this._functions, this._firestore);
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<void> submit(Map<String, Object?> payload) async {
    await _functions.httpsCallable('submitEventRatings').call<Object?>(payload);
  }

  Stream<RatingSummary> watchSummary(RatingTarget target) {
    return _firestore
        .collection('ratingSummaries')
        .doc('${target.type.name}_${target.id}')
        .snapshots()
        .map((doc) => fromAggregate(doc.data()));
  }

  /// `{ count, sum, starCounts: { '1': n, ..., '5': n } }` → resumo.
  static RatingSummary fromAggregate(Map<String, dynamic>? data) {
    if (data == null) return RatingSummary.empty;
    final rawCounts = data['starCounts'];
    final starCounts = <int, int>{
      if (rawCounts is Map)
        for (final entry in rawCounts.entries)
          if (int.tryParse('${entry.key}') case final stars?)
            stars: (entry.value as num?)?.toInt() ?? 0,
    };
    return RatingSummary.fromAggregate(
      count: (data['count'] as num?)?.toInt() ?? 0,
      sum: (data['sum'] as num?)?.toInt() ?? 0,
      starCounts: starCounts,
    );
  }
}

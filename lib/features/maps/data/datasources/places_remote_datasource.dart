import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';

class PlaceDocumentSnapshot {
  const PlaceDocumentSnapshot({
    required this.id,
    required this.data,
    required this.isFromCache,
  });

  final String id;
  final Map<String, dynamic>? data;
  final bool isFromCache;
  bool get exists => data != null;
}

class PlacesDocumentsSnapshot {
  const PlacesDocumentsSnapshot({
    required this.documents,
    required this.isFromCache,
  });

  final List<PlaceDocumentSnapshot> documents;
  final bool isFromCache;
}

abstract interface class PlacesRemoteDataSource {
  Stream<PlacesDocumentsSnapshot> watchActive({Sport? sport});
  Future<PlaceDocumentSnapshot> getById(String id);
}

class FirestorePlacesRemoteDataSource implements PlacesRemoteDataSource {
  FirestorePlacesRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<PlacesDocumentsSnapshot> watchActive({Sport? sport}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('places')
        .where('status', isEqualTo: PlaceStatus.active.name);
    if (sport != null) {
      query = query.where('sports', arrayContains: sport.storageName);
    }
    query = query.orderBy('nameLower');
    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      return PlacesDocumentsSnapshot(
        documents: snapshot.docs
            .map(
              (doc) => PlaceDocumentSnapshot(
                id: doc.id,
                data: doc.data(),
                isFromCache: snapshot.metadata.isFromCache,
              ),
            )
            .toList(growable: false),
        isFromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  @override
  Future<PlaceDocumentSnapshot> getById(String id) async {
    final snapshot = await _firestore.collection('places').doc(id).get();
    return PlaceDocumentSnapshot(
      id: snapshot.id,
      data: snapshot.data(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }
}

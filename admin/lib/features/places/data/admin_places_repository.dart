import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_place_model.dart';

enum AdminPlaceStatusFilter { all, active, inactive }

class AdminPlacesFilters {
  const AdminPlacesFilters({
    this.namePrefix = '',
    this.status = AdminPlaceStatusFilter.all,
    this.sport,
    this.cityLower = '',
  });

  final String namePrefix;
  final AdminPlaceStatusFilter status;
  final String? sport;
  final String cityLower;

  AdminPlacesFilters copyWith({
    String? namePrefix,
    AdminPlaceStatusFilter? status,
    String? sport,
    bool clearSport = false,
    String? cityLower,
  }) => AdminPlacesFilters(
    namePrefix: namePrefix ?? this.namePrefix,
    status: status ?? this.status,
    sport: clearSport ? null : sport ?? this.sport,
    cityLower: cityLower ?? this.cityLower,
  );

  @override
  bool operator ==(Object other) =>
      other is AdminPlacesFilters &&
      other.namePrefix == namePrefix &&
      other.status == status &&
      other.sport == sport &&
      other.cityLower == cityLower;

  @override
  int get hashCode => Object.hash(namePrefix, status, sport, cityLower);
}

/// Explicit query contract; its equality-filter combinations use the checked-in
/// composite indexes for `places`.
class AdminPlacesQueryPlan {
  const AdminPlacesQueryPlan({
    required this.status,
    required this.sport,
    required this.cityLower,
    required this.namePrefix,
  });

  final String? status;
  final String? sport;
  final String? cityLower;
  final String namePrefix;

  static const int pageSize = 20;

  factory AdminPlacesQueryPlan.fromFilters(AdminPlacesFilters filters) =>
      AdminPlacesQueryPlan(
        status: switch (filters.status) {
          AdminPlaceStatusFilter.all => null,
          AdminPlaceStatusFilter.active => 'active',
          AdminPlaceStatusFilter.inactive => 'inactive',
        },
        sport: filters.sport,
        cityLower: filters.cityLower.isEmpty ? null : filters.cityLower,
        namePrefix: filters.namePrefix,
      );
}

abstract interface class AdminPlaceCursor {}

class AdminPlaceSummary {
  const AdminPlaceSummary({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.city,
    required this.state,
    required this.sports,
    required this.status,
  });

  final String id;
  final String name;
  final String nameLower;
  final String city;
  final String state;
  final List<String> sports;
  final String status;

  factory AdminPlaceSummary.fromDocument(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final nameLower = data['nameLower'];
    final address = data['address'];
    final sports = data['sports'];
    final status = data['status'];
    if (name is! String ||
        nameLower is! String ||
        address is! Map ||
        address['city'] is! String ||
        address['state'] is! String ||
        sports is! List ||
        sports.any((value) => value is! String) ||
        (status != 'active' && status != 'inactive')) {
      throw FormatException('Documento places/$id não corresponde ao schema.');
    }
    return AdminPlaceSummary(
      id: id,
      name: name,
      nameLower: nameLower,
      city: address['city'] as String,
      state: address['state'] as String,
      sports: List<String>.unmodifiable(sports.cast<String>()),
      status: status as String,
    );
  }
}

class AdminPlacesPageSnapshot {
  const AdminPlacesPageSnapshot({
    required this.places,
    required this.cursor,
    required this.isFromCache,
  });

  final List<AdminPlaceSummary> places;
  final AdminPlaceCursor? cursor;
  final bool isFromCache;
}

abstract interface class AdminPlacesRepository {
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filters, {
    AdminPlaceCursor? after,
  });

  Stream<AdminPlaceRecord?> watchPlace(String id);

  Future<AdminPlaceRecord?> getPlace(String id);

  Future<String> createPlace(AdminPlaceDraft draft);

  Future<void> updatePlace(
    String id,
    AdminPlaceDraft draft, {
    required Timestamp expectedUpdatedAt,
  });

  Future<void> setPlaceStatus(
    String id,
    String status, {
    required Timestamp expectedUpdatedAt,
  });
}

enum AdminPlaceOperationErrorCode {
  notFound,
  conflict,
  alreadyInState,
  malformedDocument,
}

class AdminPlaceOperationError implements Exception {
  const AdminPlaceOperationError(this.code);

  final AdminPlaceOperationErrorCode code;

  String get message => switch (code) {
    AdminPlaceOperationErrorCode.notFound =>
      'Este Local Esportivo não existe mais. Recarregue a página.',
    AdminPlaceOperationErrorCode.conflict => 'Este local foi alterado por outra pessoa. Recarregue para revisar a versão atual.',
    AdminPlaceOperationErrorCode.alreadyInState =>
      'O local já está nesse estado. Recarregue os dados antes de continuar.',
    AdminPlaceOperationErrorCode.malformedDocument => 'Os dados atuais do local estão inválidos e não podem ser alterados com segurança.',
  };
}

class FirebaseAdminPlacesRepository implements AdminPlacesRepository {
  FirebaseAdminPlacesRepository([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int pageSize = 20;
  final FirebaseFirestore _firestore;

  @override
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filters, {
    AdminPlaceCursor? after,
  }) {
    final plan = AdminPlacesQueryPlan.fromFilters(filters);
    Query<Map<String, dynamic>> query = _firestore.collection('places');
    if (plan.status != null) {
      query = query.where('status', isEqualTo: plan.status);
    }
    if (plan.sport != null) {
      query = query.where('sports', arrayContains: plan.sport);
    }
    if (plan.cityLower != null) {
      query = query.where('address.cityLower', isEqualTo: plan.cityLower);
    }
    query = query.orderBy('nameLower');
    if (plan.namePrefix.isNotEmpty) {
      query = query.startAt(<Object?>[plan.namePrefix]).endAt(<Object?>[
        '${plan.namePrefix}\uf8ff',
      ]);
    }
    if (after != null) {
      if (after is! _FirestoreAdminPlaceCursor) {
        throw ArgumentError.value(
          after,
          'after',
          'Cursor de outra implementação.',
        );
      }
      query = query.startAfterDocument(after.document);
    }
    return query
        .limit(AdminPlacesQueryPlan.pageSize)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final places = snapshot.docs
              .map(
                (document) => AdminPlaceSummary.fromDocument(
                  document.id,
                  document.data(),
                ),
              )
              .toList(growable: false);
          final cursor = snapshot.docs.length == AdminPlacesQueryPlan.pageSize
              ? _FirestoreAdminPlaceCursor(snapshot.docs.last)
              : null;
          return AdminPlacesPageSnapshot(
            places: places,
            cursor: cursor,
            isFromCache: snapshot.metadata.isFromCache,
          );
        });
  }

  @override
  Stream<AdminPlaceRecord?> watchPlace(String id) => _firestore
      .collection('places')
      .doc(id)
      .snapshots(includeMetadataChanges: true)
      .map(
        (document) =>
            document.exists ? AdminPlaceRecord.fromDocument(document) : null,
      );

  @override
  Future<AdminPlaceRecord?> getPlace(String id) async {
    final snapshot = await _firestore
        .collection('places')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    return snapshot.exists ? AdminPlaceRecord.fromDocument(snapshot) : null;
  }

  @override
  Future<String> createPlace(AdminPlaceDraft draft) async {
    final fields = draft.toFirestoreFields();
    final reference = _firestore.collection('places').doc();
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.conflict,
        );
      }
      transaction.set(reference, <String, Object?>{
        ...fields,
        'status': 'inactive',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return reference.id;
  }

  @override
  Future<void> updatePlace(
    String id,
    AdminPlaceDraft draft, {
    required Timestamp expectedUpdatedAt,
  }) async {
    final fields = draft.toFirestoreFields();
    final reference = _firestore.collection('places').doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.notFound,
        );
      }
      final data = snapshot.data();
      final currentUpdatedAt = data?['updatedAt'];
      if (currentUpdatedAt is! Timestamp) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.malformedDocument,
        );
      }
      if (!_sameTimestamp(currentUpdatedAt, expectedUpdatedAt)) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.conflict,
        );
      }
      transaction.update(reference, <String, Object?>{
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setPlaceStatus(
    String id,
    String status, {
    required Timestamp expectedUpdatedAt,
  }) async {
    if (status != 'active' && status != 'inactive') {
      throw ArgumentError.value(status, 'status');
    }
    final reference = _firestore.collection('places').doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.notFound,
        );
      }
      final data = snapshot.data();
      final currentUpdatedAt = data?['updatedAt'];
      final currentStatus = data?['status'];
      if (currentUpdatedAt is! Timestamp ||
          (currentStatus != 'active' && currentStatus != 'inactive')) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.malformedDocument,
        );
      }
      if (!_sameTimestamp(currentUpdatedAt, expectedUpdatedAt)) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.conflict,
        );
      }
      if (currentStatus == status) {
        throw const AdminPlaceOperationError(
          AdminPlaceOperationErrorCode.alreadyInState,
        );
      }
      transaction.update(reference, <String, Object?>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

bool _sameTimestamp(Timestamp left, Timestamp right) =>
    left.seconds == right.seconds && left.nanoseconds == right.nanoseconds;

class _FirestoreAdminPlaceCursor implements AdminPlaceCursor {
  const _FirestoreAdminPlaceCursor(this.document);

  final DocumentSnapshot<Map<String, dynamic>> document;
}

String normalizeAdminSearch(String value) {
  const accents = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final lower = value.trim().toLowerCase();
  return String.fromCharCodes(
    lower.runes.map((rune) {
      final char = String.fromCharCode(rune);
      return (accents[char] ?? char).runes.first;
    }),
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.profileCount,
    required this.activePlaceCount,
    required this.inactivePlaceCount,
  });

  final int profileCount;
  final int activePlaceCount;
  final int inactivePlaceCount;
}

class AdminDashboardCountQuery {
  const AdminDashboardCountQuery({
    required this.collection,
    this.filterField,
    this.filterValue,
  });

  final String collection;
  final String? filterField;
  final String? filterValue;

  static const List<AdminDashboardCountQuery> definitions =
      <AdminDashboardCountQuery>[
        AdminDashboardCountQuery(collection: 'users'),
        AdminDashboardCountQuery(
          collection: 'places',
          filterField: 'status',
          filterValue: 'active',
        ),
        AdminDashboardCountQuery(
          collection: 'places',
          filterField: 'status',
          filterValue: 'inactive',
        ),
      ];
}

abstract interface class AdminDashboardRepository {
  Future<AdminDashboardMetrics> loadMetrics();
}

class FirebaseAdminDashboardRepository implements AdminDashboardRepository {
  FirebaseAdminDashboardRepository([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<AdminDashboardMetrics> loadMetrics() async {
    final counts = await Future.wait<int>(
      AdminDashboardCountQuery.definitions.map(_count),
    );
    return AdminDashboardMetrics(
      profileCount: counts[0],
      activePlaceCount: counts[1],
      inactivePlaceCount: counts[2],
    );
  }

  Future<int> _count(AdminDashboardCountQuery definition) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      definition.collection,
    );
    if (definition.filterField != null) {
      query = query.where(
        definition.filterField!,
        isEqualTo: definition.filterValue,
      );
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }
}

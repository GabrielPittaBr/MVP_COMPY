import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.profileCount,
    required this.activePlaceCount,
    required this.inactivePlaceCount,
    required this.eventCount,
    required this.upcomingEventCount,
  });

  final int profileCount;
  final int activePlaceCount;
  final int inactivePlaceCount;
  final int eventCount;

  /// Eventos que ainda não começaram.
  final int upcomingEventCount;
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
        AdminDashboardCountQuery(collection: 'events'),
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
    final counts = await Future.wait<int>(<Future<int>>[
      ...AdminDashboardCountQuery.definitions.map(_count),
      _countUpcomingEvents(),
    ]);
    return AdminDashboardMetrics(
      profileCount: counts[0],
      activePlaceCount: counts[1],
      inactivePlaceCount: counts[2],
      eventCount: counts[3],
      upcomingEventCount: counts[4],
    );
  }

  /// Faixa no próprio `dateTime`: o índice simples do campo basta.
  Future<int> _countUpcomingEvents() async {
    final snapshot = await _firestore
        .collection('events')
        .where('dateTime', isGreaterThan: Timestamp.now())
        .count()
        .get();
    return snapshot.count ?? 0;
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

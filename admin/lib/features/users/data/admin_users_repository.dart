import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../places/data/admin_places_repository.dart';

enum AdminUserSearchType { name, handle, uid, email }

enum AdminUserAuthState { active, suspended, notFound, unavailable }

enum AdminUserSuspensionAction { suspend, reactivate }

class AdminUserProfile {
  const AdminUserProfile({
    required this.uid,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.favoriteSports,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String handle;
  final String avatarUrl;
  final List<String> favoriteSports;
  final DateTime? createdAt;

  factory AdminUserProfile.fromDocument(String uid, Map<String, dynamic> data) {
    final rawSports = data['favoriteSports'];
    final rawCreatedAt = data['createdAt'];
    return AdminUserProfile(
      uid: uid,
      name: data['name'] is String ? data['name'] as String : '',
      handle: data['handle'] is String ? data['handle'] as String : '',
      avatarUrl: data['avatarUrl'] is String ? data['avatarUrl'] as String : '',
      favoriteSports: List<String>.unmodifiable(
        rawSports is List ? rawSports.whereType<String>().toSet() : <String>{},
      ),
      createdAt: switch (rawCreatedAt) {
        Timestamp value => value.toDate(),
        DateTime value => value,
        _ => null,
      },
    );
  }
}

/// Deliberately narrow: the panel never models or renders private Auth fields.
class AdminUserAuthDetails {
  const AdminUserAuthDetails({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.providerIds,
    required this.createdAt,
    required this.lastSignInAt,
    required this.disabled,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final List<String> providerIds;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final bool disabled;

  factory AdminUserAuthDetails.fromCallable(Object? value) {
    if (value is! Map) {
      throw const FormatException('Retorno Auth administrativo inválido.');
    }
    final uid = value['uid'];
    final email = value['email'];
    final emailVerified = value['emailVerified'];
    final providerIds = value['providerIds'];
    final disabled = value['disabled'];
    if (uid is! String ||
        uid.isEmpty ||
        (email != null && email is! String) ||
        emailVerified is! bool ||
        disabled is! bool ||
        providerIds is! List ||
        providerIds.any((item) => item is! String)) {
      throw const FormatException('Retorno Auth administrativo inválido.');
    }
    return AdminUserAuthDetails(
      uid: uid,
      email: email as String?,
      emailVerified: emailVerified,
      providerIds: List<String>.unmodifiable(providerIds.cast<String>()),
      createdAt: _parseDate(value['createdAt']),
      lastSignInAt: _parseDate(value['lastSignInAt']),
      disabled: disabled,
    );
  }
}

class AdminUserSuspensionResult {
  const AdminUserSuspensionResult({
    required this.uid,
    required this.disabled,
    required this.action,
    required this.completedAt,
  });

  final String uid;
  final bool disabled;
  final AdminUserSuspensionAction action;
  final DateTime completedAt;

  factory AdminUserSuspensionResult.fromCallable(Object? value) {
    if (value is! Map ||
        value['uid'] is! String ||
        (value['uid'] as String).isEmpty ||
        value['disabled'] is! bool ||
        (value['action'] != 'suspend' && value['action'] != 'reactivate') ||
        value['completedAt'] is! String) {
      throw const FormatException(
        'Retorno da operação administrativa inválido.',
      );
    }
    final completedAt = DateTime.tryParse(value['completedAt'] as String);
    if (completedAt == null) {
      throw const FormatException(
        'Retorno da operação administrativa inválido.',
      );
    }
    return AdminUserSuspensionResult(
      uid: value['uid'] as String,
      disabled: value['disabled'] as bool,
      action: value['action'] == 'suspend'
          ? AdminUserSuspensionAction.suspend
          : AdminUserSuspensionAction.reactivate,
      completedAt: completedAt.toUtc(),
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class AdminUserListItem {
  const AdminUserListItem({required this.profile, required this.authState});

  final AdminUserProfile profile;
  final AdminUserAuthState authState;
}

abstract interface class AdminUserCursor {}

class AdminUsersPageSnapshot {
  const AdminUsersPageSnapshot({
    required this.items,
    required this.cursor,
    required this.isFromCache,
  });

  final List<AdminUserListItem> items;
  final AdminUserCursor? cursor;
  final bool isFromCache;
}

class AdminUserDetailsResult {
  const AdminUserDetailsResult({
    required this.uid,
    required this.profile,
    required this.auth,
    required this.profileNotFound,
    required this.profileUnavailable,
    required this.profileFromCache,
    required this.authNotFound,
    required this.authUnavailable,
  });

  final String uid;
  final AdminUserProfile? profile;
  final AdminUserAuthDetails? auth;
  final bool profileNotFound;
  final bool profileUnavailable;
  final bool profileFromCache;
  final bool authNotFound;
  final bool authUnavailable;
}

class AdminUsersQueryPlan {
  const AdminUsersQueryPlan({required this.field, required this.prefix});

  final String field;
  final String prefix;

  static const int pageSize = 20;

  factory AdminUsersQueryPlan.fromSearch(
    AdminUserSearchType type,
    String rawQuery,
  ) {
    return switch (type) {
      AdminUserSearchType.name => AdminUsersQueryPlan(
        field: 'nameLower',
        prefix: normalizeAdminSearch(rawQuery),
      ),
      AdminUserSearchType.handle => AdminUsersQueryPlan(
        field: 'handle',
        prefix: '@${rawQuery.trim().toLowerCase().replaceFirst('@', '')}',
      ),
      AdminUserSearchType.uid || AdminUserSearchType.email =>
        throw ArgumentError('UID e e-mail usam consulta Auth exata.'),
    };
  }
}

typedef AdminUsersCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, Object?> payload,
);

/// Narrow client boundary for administrative Auth Callables. The injectable
/// invoker lets tests verify exact function names and whitelisted payloads.
class AdminUsersCallableClient {
  AdminUsersCallableClient({this.functions, this.invoker});

  final FirebaseFunctions? functions;
  final AdminUsersCallableInvoker? invoker;

  Future<Object?> getAdminUserAuthDetails({String? uid, String? email}) {
    if ((uid == null) == (email == null)) {
      throw ArgumentError('Informe exatamente um UID ou e-mail.');
    }
    final payload = uid != null
        ? <String, Object?>{'uid': uid}
        : <String, Object?>{'email': email!.trim().toLowerCase()};
    return _call('getAdminUserAuthDetails', payload);
  }

  Future<Object?> getAdminUsersAuthStatus(List<String> uids) =>
      _call('getAdminUsersAuthStatus', <String, Object?>{'uids': uids});

  Future<AdminUserSuspensionResult> setUserSuspension({
    required String uid,
    required AdminUserSuspensionAction action,
    required String reason,
    required String operationId,
  }) async {
    final response = await _call('setUserSuspension', <String, Object?>{
      'uid': uid,
      'action': action == AdminUserSuspensionAction.suspend
          ? 'suspend'
          : 'reactivate',
      'reason': normalizeAdminSuspensionReason(reason),
      'operationId': operationId,
    });
    return AdminUserSuspensionResult.fromCallable(response);
  }

  Future<Object?> _call(String name, Map<String, Object?> payload) async {
    final testInvoker = invoker;
    if (testInvoker != null) return testInvoker(name, payload);
    final functions =
        this.functions ??
        FirebaseFunctions.instanceFor(region: 'southamerica-east1');
    final result = await functions.httpsCallable(name).call<Object?>(payload);
    return result.data;
  }
}

String normalizeAdminSuspensionReason(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

abstract interface class AdminUsersRepository {
  Future<AdminUsersPageSnapshot> searchProfiles(
    AdminUserSearchType type,
    String query, {
    AdminUserCursor? after,
  });

  Future<AdminUserDetailsResult?> findExact(
    AdminUserSearchType type,
    String query,
  );

  Future<AdminUserDetailsResult> loadDetails(String uid);

  Future<AdminUserSuspensionResult> setUserSuspension({
    required String uid,
    required AdminUserSuspensionAction action,
    required String reason,
    required String operationId,
  });
}

class FirebaseAdminUsersRepository implements AdminUsersRepository {
  FirebaseAdminUsersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AdminUsersCallableClient? callableClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _callableClient =
           callableClient ?? AdminUsersCallableClient(functions: functions);

  final FirebaseFirestore _firestore;
  final AdminUsersCallableClient _callableClient;

  @override
  Future<AdminUsersPageSnapshot> searchProfiles(
    AdminUserSearchType type,
    String query, {
    AdminUserCursor? after,
  }) async {
    if (type != AdminUserSearchType.name &&
        type != AdminUserSearchType.handle) {
      throw ArgumentError('Somente Nome e Handle listam perfis paginados.');
    }
    final plan = AdminUsersQueryPlan.fromSearch(type, query);
    Query<Map<String, dynamic>> request = _firestore
        .collection('users')
        .orderBy(plan.field);
    if (plan.prefix.isNotEmpty) {
      request = request.startAt(<Object?>[plan.prefix]).endAt(<Object?>[
        '${plan.prefix}\uf8ff',
      ]);
    }
    if (after != null) {
      if (after is! _FirestoreAdminUserCursor) {
        throw ArgumentError.value(after, 'after', 'Cursor incompatível.');
      }
      request = request.startAfterDocument(after.document);
    }
    final result = await request.limit(AdminUsersQueryPlan.pageSize).get();
    final profiles = result.docs
        .map((doc) => AdminUserProfile.fromDocument(doc.id, doc.data()))
        .toList(growable: false);
    final statuses = await _loadAuthStatuses(profiles);
    final items = profiles
        .map(
          (profile) => AdminUserListItem(
            profile: profile,
            authState: statuses[profile.uid] ?? AdminUserAuthState.notFound,
          ),
        )
        .toList(growable: false);
    return AdminUsersPageSnapshot(
      items: items,
      cursor: result.docs.length == AdminUsersQueryPlan.pageSize
          ? _FirestoreAdminUserCursor(result.docs.last)
          : null,
      isFromCache: result.metadata.isFromCache,
    );
  }

  Future<Map<String, AdminUserAuthState>> _loadAuthStatuses(
    List<AdminUserProfile> profiles,
  ) async {
    if (profiles.isEmpty) return const <String, AdminUserAuthState>{};
    try {
      final data = await _callableClient.getAdminUsersAuthStatus(
        profiles.map((profile) => profile.uid).toList(growable: false),
      );
      if (data is! Map || data['items'] is! List) {
        throw const FormatException('Retorno de estado Auth inválido.');
      }
      final found = <String, AdminUserAuthState>{};
      for (final item in (data['items'] as List)) {
        if (item is! Map ||
            item['uid'] is! String ||
            item['disabled'] is! bool) {
          throw const FormatException('Retorno de estado Auth inválido.');
        }
        final uid = item['uid'] as String;
        if (profiles.any((profile) => profile.uid == uid)) {
          found[uid] = item['disabled'] as bool
              ? AdminUserAuthState.suspended
              : AdminUserAuthState.active;
        }
      }
      return found;
    } on Object {
      return <String, AdminUserAuthState>{
        for (final profile in profiles)
          profile.uid: AdminUserAuthState.unavailable,
      };
    }
  }

  @override
  Future<AdminUserDetailsResult?> findExact(
    AdminUserSearchType type,
    String query,
  ) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;
    switch (type) {
      case AdminUserSearchType.uid:
        final result = await loadDetails(normalized);
        return result.profile == null &&
                result.auth == null &&
                result.authNotFound &&
                !result.profileUnavailable
            ? null
            : result;
      case AdminUserSearchType.email:
        final authLookup = await _lookupAuth(email: normalized.toLowerCase());
        if (authLookup.notFound) return null;
        final auth = authLookup.details;
        if (auth == null) {
          throw StateError('Estado Auth indisponível para a consulta exata.');
        }
        final profileRead = await _readProfile(auth.uid);
        return _detailsResult(auth.uid, profileRead, authLookup);
      case AdminUserSearchType.name:
      case AdminUserSearchType.handle:
        throw ArgumentError('Nome e Handle usam listagem paginada.');
    }
  }

  @override
  Future<AdminUserDetailsResult> loadDetails(String uid) async {
    final reads = await Future.wait<Object>(<Future<Object>>[
      _readProfile(uid),
      _lookupAuth(uid: uid),
    ]);
    return _detailsResult(uid, reads[0] as _ProfileRead, reads[1] as _AuthRead);
  }

  @override
  Future<AdminUserSuspensionResult> setUserSuspension({
    required String uid,
    required AdminUserSuspensionAction action,
    required String reason,
    required String operationId,
  }) => _callableClient.setUserSuspension(
    uid: uid,
    action: action,
    reason: reason,
    operationId: operationId,
  );

  Future<_ProfileRead> _readProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return _ProfileRead(
      profile: doc.exists
          ? AdminUserProfile.fromDocument(uid, doc.data()!)
          : null,
      fromCache: doc.metadata.isFromCache,
      confirmedMissing: !doc.exists && !doc.metadata.isFromCache,
    );
  }

  Future<_AuthRead> _lookupAuth({String? uid, String? email}) async {
    try {
      final response = await _callableClient.getAdminUserAuthDetails(
        uid: uid,
        email: email,
      );
      return _AuthRead(details: AdminUserAuthDetails.fromCallable(response));
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') return const _AuthRead(notFound: true);
      return const _AuthRead(unavailable: true);
    } on Object {
      return const _AuthRead(unavailable: true);
    }
  }

  AdminUserDetailsResult _detailsResult(
    String uid,
    _ProfileRead profile,
    _AuthRead auth,
  ) => AdminUserDetailsResult(
    uid: uid,
    profile: profile.profile,
    auth: auth.details,
    profileNotFound: profile.confirmedMissing,
    profileUnavailable: profile.profile == null && !profile.confirmedMissing,
    profileFromCache: profile.fromCache,
    authNotFound: auth.notFound,
    authUnavailable: auth.unavailable,
  );
}

class _ProfileRead {
  const _ProfileRead({
    required this.profile,
    required this.fromCache,
    required this.confirmedMissing,
  });

  final AdminUserProfile? profile;
  final bool fromCache;
  final bool confirmedMissing;
}

class _AuthRead {
  const _AuthRead({
    this.details,
    this.notFound = false,
    this.unavailable = false,
  });

  final AdminUserAuthDetails? details;
  final bool notFound;
  final bool unavailable;
}

class _FirestoreAdminUserCursor implements AdminUserCursor {
  const _FirestoreAdminUserCursor(this.document);

  final DocumentSnapshot<Map<String, dynamic>> document;
}

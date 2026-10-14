import 'dart:async';

import 'package:compy_admin/app.dart';
import 'package:compy_admin/core/constants/admin_strings.dart';
import 'package:compy_admin/core/routing/admin_router.dart';
import 'package:compy_admin/core/shell/admin_shell.dart';
import 'package:compy_admin/features/auth/presentation/admin_auth_feature.dart';
import 'package:compy_admin/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:compy_admin/features/places/data/admin_places_repository.dart';
import 'package:compy_admin/features/users/data/admin_users_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guard protege deep links e mantém apenas as rotas públicas abertas',
    () {
      expect(
        redirectForAdminRoute(
          location: '/users/a-user',
          accessState: AdminAccessState.signedOut,
        ),
        '/login',
      );
      expect(
        redirectForAdminRoute(
          location: '/places/new',
          accessState: AdminAccessState.unauthorized,
        ),
        '/unauthorized',
      );
      expect(
        redirectForAdminRoute(
          location: '/login',
          accessState: AdminAccessState.authorized,
        ),
        '/dashboard',
      );
      expect(
        redirectForAdminRoute(
          location: '/unauthorized',
          accessState: AdminAccessState.unauthorized,
        ),
        isNull,
      );
    },
  );

  test('guard preserva deep link até autenticação e rejeita destino externo', () {
    for (final destination in <String>['/dashboard', '/users', '/places']) {
      final redirect = redirectForAdminRoute(
        location: Uri.parse(destination).path,
        accessState: AdminAccessState.signedOut,
        requestedLocation: destination,
      );
      expect(Uri.parse(redirect!).path, '/login');
      final restoredDestination = Uri.parse(redirect).queryParameters['from'];
      expect(restoredDestination, destination);
      expect(
        redirectForAdminRoute(
          location: '/login',
          accessState: AdminAccessState.authorized,
          requestedLocation: restoredDestination,
        ),
        destination,
      );
    }

    final signedOutRedirect = redirectForAdminRoute(
      location: '/users',
      accessState: AdminAccessState.signedOut,
      requestedLocation: '/users/a-user',
    );
    expect(Uri.parse(signedOutRedirect!).path, '/login');
    expect(
      Uri.parse(signedOutRedirect).queryParameters['from'],
      '/users/a-user',
    );

    expect(
      redirectForAdminRoute(
        location: '/login',
        accessState: AdminAccessState.authorized,
        requestedLocation: '/places?status=inactive',
      ),
      '/places?status=inactive',
    );
    expect(
      redirectForAdminRoute(
        location: '/login',
        accessState: AdminAccessState.authorized,
        requestedLocation: 'https://example.invalid',
      ),
      '/dashboard',
    );
    expect(
      redirectForAdminRoute(
        location: '/login',
        accessState: AdminAccessState.authorized,
        requestedLocation: '//example.invalid',
      ),
      '/dashboard',
    );
  });

  test('breakpoint do shell separa sidebar permanente e recolhível', () {
    expect(usesDesktopAdminNavigation(839), isFalse);
    expect(usesDesktopAdminNavigation(840), isTrue);
  });

  test('sessão sem todos os requisitos administrativos é encerrada', () async {
    final gateway = _FakeAdminAuthGateway(
      candidate: const AdminAuthCandidate(
        uid: 'not-admin',
        email: 'person@example.com',
        emailVerified: true,
        providerIds: <String>{'password'},
        claims: <String, Object?>{},
      ),
    );
    final controller = AdminAuthController(gateway);

    await controller.start();

    expect(gateway.usedSessionPersistence, isTrue);
    expect(gateway.signOutCalls, 1);
    expect(controller.state, AdminAccessState.unauthorized);
    expect(controller.session, isNull);
    controller.dispose();
  });

  testWidgets(
    'mostra carregamento até Firebase e autorização estarem resolvidos',
    (tester) async {
      final initialization = Completer<void>();
      final authorization = Completer<AdminAuthCandidate?>();

      await tester.pumpWidget(
        CompyAdminBootstrap(
          initialize: () => initialization.future,
          authGatewayFactory: () =>
              _FakeAdminAuthGateway(candidateFuture: authorization.future),
        ),
      );

      expect(find.text(AdminStrings.initializingTitle), findsOneWidget);
      initialization.complete();
      await tester.pump();
      expect(find.text(AdminStrings.authorizationLoadingTitle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      authorization.complete(null);
      await tester.pumpAndSettle();
      expect(find.text(AdminStrings.loginTitle), findsOneWidget);
    },
  );

  testWidgets('login usa somente e-mail e senha e libera o shell autorizado', (
    tester,
  ) async {
    final gateway = _FakeAdminAuthGateway(candidate: null)
      ..candidateAfterLogin = const AdminAuthCandidate(
        uid: 'admin-uid',
        email: 'admin@compy.app',
        emailVerified: true,
        providerIds: <String>{'password'},
        claims: <String, Object?>{'admin': true},
      );

    await tester.pumpWidget(
      CompyAdminApp(
        authGateway: gateway,
        dashboardRepository: _FakeAdminDashboardRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AdminStrings.loginTitle), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      ' admin@compy.app ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'secret',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(gateway.lastLoginEmail, 'admin@compy.app');
    expect(gateway.lastLoginPassword, 'secret');
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byTooltip('Sair'), findsOneWidget);
  });

  testWidgets('deep link de usuário usa o mesmo guard no shell desktop', (
    tester,
  ) async {
    final authorizedGateway = _FakeAdminAuthGateway(
      candidate: _authorizedCandidate,
    );
    await tester.pumpWidget(
      CompyAdminApp(
        authGateway: authorizedGateway,
        initialLocation: '/users/a-user',
        usersRepository: _FakeAdminUsersRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do Usuário'), findsOneWidget);
    expect(find.byTooltip('Sair'), findsOneWidget);
  });

  testWidgets(
    'deep link volta ao destino original quando a sessão Admin é restaurada',
    (tester) async {
      final gateway = _FakeAdminAuthGateway(candidate: null);
      await tester.pumpWidget(
        CompyAdminApp(
          authGateway: gateway,
          initialLocation: '/users/a-user',
          usersRepository: _FakeAdminUsersRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AdminStrings.loginTitle), findsOneWidget);

      gateway.candidate = _authorizedCandidate;
      gateway.authEvents.add(null);
      await tester.pumpAndSettle();

      expect(find.text('Detalhes do Usuário'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);

      await gateway.authEvents.close();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('atalho de locais inativos aplica o filtro explicitamente', (
    tester,
  ) async {
    final gateway = _FakeAdminAuthGateway(candidate: _authorizedCandidate);
    final placesRepository = _FakeAdminPlacesRepository();
    await tester.pumpWidget(
      CompyAdminApp(
        authGateway: gateway,
        dashboardRepository: _FakeAdminDashboardRepository(),
        placesRepository: placesRepository,
        initialLocation: '/dashboard',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visão geral'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver locais inativos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(placesRepository.filters, hasLength(1));
    expect(
      placesRepository.filters.single.status,
      AdminPlaceStatusFilter.inactive,
    );
    expect(find.text('Locais Esportivos'), findsWidgets);
  });

  testWidgets(
    'tela não autorizada oferece retorno ao login com foco acessível',
    (tester) async {
      final gateway = _FakeAdminAuthGateway(
        candidate: const AdminAuthCandidate(
          uid: 'unverified-admin',
          email: 'admin@compy.app',
          emailVerified: false,
          providerIds: <String>{'password'},
          claims: <String, Object?>{'admin': true},
        ),
      );

      await tester.pumpWidget(CompyAdminApp(authGateway: gateway));
      await tester.pumpAndSettle();

      expect(find.text(AdminStrings.unauthorizedTitle), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(
        find.widgetWithText(FilledButton, 'Voltar ao login'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Voltar ao login'));
      await tester.pumpAndSettle();
      expect(find.text(AdminStrings.loginTitle), findsOneWidget);
    },
  );
}

const _authorizedCandidate = AdminAuthCandidate(
  uid: 'admin-uid',
  email: 'admin@compy.app',
  emailVerified: true,
  providerIds: <String>{'password'},
  claims: <String, Object?>{'admin': true},
);

class _FakeAdminAuthGateway implements AdminAuthGateway {
  _FakeAdminAuthGateway({this.candidate, this.candidateFuture});

  final StreamController<void> authEvents = StreamController<void>.broadcast();
  AdminAuthCandidate? candidate;
  Future<AdminAuthCandidate?>? candidateFuture;
  AdminAuthCandidate? candidateAfterLogin;
  bool usedSessionPersistence = false;
  int signOutCalls = 0;
  String? lastLoginEmail;
  String? lastLoginPassword;

  @override
  Stream<void> get authStateChanges => authEvents.stream;

  @override
  Future<AdminAuthCandidate?> refreshCurrentSession() async =>
      candidateFuture == null ? candidate : candidateFuture!;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    candidate = candidateAfterLogin;
    candidateFuture = null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    candidate = null;
  }

  @override
  Future<void> useSessionPersistence() async {
    usedSessionPersistence = true;
  }
}

class _FakeAdminDashboardRepository implements AdminDashboardRepository {
  @override
  Future<AdminDashboardMetrics> loadMetrics() async =>
      const AdminDashboardMetrics(
        profileCount: 0,
        activePlaceCount: 0,
        inactivePlaceCount: 0,
      );
}

class _FakeAdminPlacesRepository implements AdminPlacesRepository {
  final List<AdminPlacesFilters> filters = <AdminPlacesFilters>[];

  @override
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filter, {
    AdminPlaceCursor? after,
  }) {
    filters.add(filter);
    return const Stream<AdminPlacesPageSnapshot>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAdminUsersRepository implements AdminUsersRepository {
  @override
  Future<AdminUserDetailsResult?> findExact(
    AdminUserSearchType type,
    String query,
  ) async => null;

  @override
  Future<AdminUserDetailsResult> loadDetails(String uid) async =>
      AdminUserDetailsResult(
        uid: uid,
        profile: null,
        auth: null,
        profileNotFound: true,
        profileUnavailable: false,
        profileFromCache: false,
        authNotFound: true,
        authUnavailable: false,
      );

  @override
  Future<AdminUserSuspensionResult> setUserSuspension({
    required String uid,
    required AdminUserSuspensionAction action,
    required String reason,
    required String operationId,
  }) async => AdminUserSuspensionResult(
    uid: uid,
    disabled: action == AdminUserSuspensionAction.suspend,
    action: action,
    completedAt: DateTime.utc(2026),
  );

  @override
  Future<AdminUsersPageSnapshot> searchProfiles(
    AdminUserSearchType type,
    String query, {
    AdminUserCursor? after,
  }) async => const AdminUsersPageSnapshot(
    items: <AdminUserListItem>[],
    cursor: null,
    isFromCache: false,
  );
}

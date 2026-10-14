import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/admin_auth_feature.dart';
import '../../features/auth/presentation/admin_auth_screens.dart';
import '../../features/dashboard/data/admin_dashboard_repository.dart';
import '../../features/dashboard/presentation/admin_dashboard_page.dart';
import '../../features/places/data/admin_places_repository.dart';
import '../../features/places/presentation/admin_place_form_page.dart';
import '../../features/places/presentation/admin_places_page.dart';
import '../../features/users/data/admin_users_repository.dart';
import '../../features/users/presentation/admin_users_pages.dart';
import '../shell/admin_shell.dart';

const _publicRoutes = <String>{'/login', '/unauthorized'};

String? _validatedAdminDestination(String? value) {
  if (value == null || value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.path.contains('\\') ||
      uri.pathSegments.any((segment) => segment == '.' || segment == '..')) {
    return null;
  }

  final path = uri.path;
  final isPlaceDetails =
      path.startsWith('/places/') &&
      path.substring('/places/'.length).isNotEmpty &&
      !path.substring('/places/'.length).contains('/');
  final isUserDetails =
      path.startsWith('/users/') &&
      path.substring('/users/'.length).isNotEmpty &&
      !path.substring('/users/'.length).contains('/');
  final isKnownProtectedRoute = path == '/dashboard' ||
      path == '/places' ||
      path == '/places/new' ||
      isPlaceDetails ||
      path == '/users' ||
      isUserDetails;

  return isKnownProtectedRoute ? uri.toString() : null;
}

/// Decisão pura para testar redirecionamentos e deep links sem Firebase.
String? redirectForAdminRoute({
  required String location,
  required AdminAccessState accessState,
  String? requestedLocation,
}) {
  final isPublicRoute = _publicRoutes.contains(location);
  final returnDestination = _validatedAdminDestination(requestedLocation);
  final loginLocation = returnDestination == null
      ? '/login'
      : Uri(
          path: '/login',
          queryParameters: <String, String>{'from': returnDestination},
        ).toString();

  return switch (accessState) {
    AdminAccessState.authorized => isPublicRoute
        ? location == '/login'
              ? returnDestination ?? '/dashboard'
              : '/dashboard'
        : null,
    AdminAccessState.unauthorized =>
      location == '/unauthorized' ? null : '/unauthorized',
    AdminAccessState.signedOut ||
    AdminAccessState.loading => isPublicRoute
        ? null
        : loginLocation,
  };
}

GoRouter createAdminRouter({
  required AdminAuthController authController,
  String? initialLocation,
  AdminDashboardRepository? dashboardRepository,
  AdminPlacesRepository? placesRepository,
  AdminUsersRepository? usersRepository,
}) {
  return GoRouter(
    initialLocation: initialLocation ?? '/dashboard',
    refreshListenable: authController,
    redirect: (context, state) {
      final location = state.uri.path;
      return redirectForAdminRoute(
        location: location,
        accessState: authController.state,
        requestedLocation: location == '/login'
            ? state.uri.queryParameters['from']
            : state.uri.toString(),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            AdminLoginScreen(controller: authController),
      ),
      GoRoute(
        path: '/unauthorized',
        builder: (context, state) =>
            AdminUnauthorizedScreen(controller: authController),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => AdminShell(
          controller: authController,
          location: state.uri.path,
          child: AdminDashboardPage(repository: dashboardRepository),
        ),
      ),
      GoRoute(
        path: '/places',
        builder: (context, state) {
          final initialStatus =
              state.uri.queryParameters['status'] == 'inactive'
              ? AdminPlaceStatusFilter.inactive
              : AdminPlaceStatusFilter.all;
          return AdminShell(
            controller: authController,
            location: state.uri.path,
            child: AdminPlacesPage(
              repository: placesRepository,
              initialStatus: initialStatus,
            ),
          );
        },
      ),
      GoRoute(
        path: '/places/new',
        builder: (context, state) => AdminShell(
          controller: authController,
          location: state.uri.path,
          child: AdminPlaceFormPage(
            repository: placesRepository ?? FirebaseAdminPlacesRepository(),
          ),
        ),
      ),
      GoRoute(
        path: '/places/:id',
        builder: (context, state) => AdminShell(
          controller: authController,
          location: state.uri.path,
          child: AdminPlaceFormPage(
            placeId: state.pathParameters['id']!,
            repository: placesRepository ?? FirebaseAdminPlacesRepository(),
          ),
        ),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => AdminShell(
          controller: authController,
          location: state.uri.path,
          child: AdminUsersPage(repository: usersRepository),
        ),
      ),
      GoRoute(
        path: '/users/:uid',
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          final extra = state.extra;
          return AdminShell(
            controller: authController,
            location: state.uri.path,
            child: AdminUserDetailsPage(
              uid: uid,
              repository: usersRepository,
              initialDetails: extra is AdminUserDetailsResult ? extra : null,
            ),
          );
        },
      ),
    ],
  );
}

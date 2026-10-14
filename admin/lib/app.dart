import 'package:flutter/material.dart';

import 'core/constants/admin_strings.dart';
import 'core/routing/admin_router.dart';
import 'core/theme/admin_theme.dart';
import 'features/auth/presentation/admin_auth_feature.dart';
import 'features/dashboard/data/admin_dashboard_repository.dart';
import 'features/places/data/admin_places_repository.dart';
import 'features/users/data/admin_users_repository.dart';

typedef FirebaseInitializer = Future<void> Function();

/// Limite de inicialização do painel.
///
/// O shell, as rotas protegidas e as leituras administrativas entram no ticket
/// de autenticação. Até lá, este widget garante que o Firebase esteja pronto
/// antes de exibir a fundação neutra do app.
class CompyAdminBootstrap extends StatefulWidget {
  const CompyAdminBootstrap({
    required this.initialize,
    this.authGatewayFactory = FirebaseAdminAuthGateway.new,
    super.key,
  });

  final FirebaseInitializer initialize;
  final AdminAuthGateway Function() authGatewayFactory;

  @override
  State<CompyAdminBootstrap> createState() => _CompyAdminBootstrapState();
}

class _CompyAdminBootstrapState extends State<CompyAdminBootstrap> {
  late final Future<void> _initialization = widget.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            title: AdminStrings.appTitle,
            theme: AdminTheme.light,
            home: const _AdminStartupScreen(
              title: AdminStrings.initializationErrorTitle,
              body: AdminStrings.initializationErrorBody,
              icon: Icons.cloud_off_outlined,
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: AdminStrings.appTitle,
            theme: AdminTheme.light,
            home: const _AdminStartupScreen(
              title: AdminStrings.initializingTitle,
              body: AdminStrings.initializingBody,
              showProgress: true,
            ),
          );
        }

        return CompyAdminApp(authGateway: widget.authGatewayFactory());
      },
    );
  }
}

/// O shell nunca é renderizado antes da validação completa da sessão.
class CompyAdminApp extends StatefulWidget {
  const CompyAdminApp({
    required this.authGateway,
    this.initialLocation,
    this.dashboardRepository,
    this.placesRepository,
    this.usersRepository,
    super.key,
  });

  final AdminAuthGateway authGateway;
  final String? initialLocation;
  final AdminDashboardRepository? dashboardRepository;
  final AdminPlacesRepository? placesRepository;
  final AdminUsersRepository? usersRepository;

  @override
  State<CompyAdminApp> createState() => _CompyAdminAppState();
}

class _CompyAdminAppState extends State<CompyAdminApp> {
  late final AdminAuthController _authController = AdminAuthController(
    widget.authGateway,
  );
  late final _router = createAdminRouter(
    authController: _authController,
    initialLocation: widget.initialLocation,
    dashboardRepository: widget.dashboardRepository,
    placesRepository: widget.placesRepository,
    usersRepository: widget.usersRepository,
  );

  @override
  void initState() {
    super.initState();
    _authController.addListener(_onAccessChanged);
    _authController.start();
  }

  void _onAccessChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_onAccessChanged);
    _router.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authController.state == AdminAccessState.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AdminStrings.appTitle,
        theme: AdminTheme.light,
        home: const _AdminStartupScreen(
          title: AdminStrings.authorizationLoadingTitle,
          body: AdminStrings.authorizationLoadingBody,
          showProgress: true,
        ),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AdminStrings.appTitle,
      theme: AdminTheme.light,
      routerConfig: _router,
    );
  }
}

class _AdminStartupScreen extends StatelessWidget {
  const _AdminStartupScreen({
    required this.title,
    required this.body,
    this.icon = Icons.admin_panel_settings_outlined,
    this.showProgress = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(body, textAlign: TextAlign.center),
                  if (showProgress) ...<Widget>[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

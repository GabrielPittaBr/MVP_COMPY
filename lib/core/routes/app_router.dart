import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/username_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/events_list_page.dart';
import '../../features/events/presentation/pages/search_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/maps/presentation/pages/maps_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../shared/widgets/app_bottom_nav.dart';

/// Caminhos das principais telas — centralizados para evitar strings espalhadas.
abstract final class AppRoutes {
  // Splash (carregamento inicial)
  static const String splash = '/';

  // Auth (fora do shell — sem bottom nav)
  static const String login = '/login';
  static const String signup = '/signup';
  static const String username = '/username';

  // App (dentro do shell com 5 abas)
  static const String home = '/home';
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String create = '/create';
  static const String chat = '/chat';
  static const String chatRoom = '/chat/:conversationId';
  static const String profile = '/profile';

  /// Mapa fica como sub-rota da home para preservar o bottom nav (mockup).
  static const String maps = '/home/maps';

  /// Busca de eventos — sub-rota da home (aberta pelo SearchField).
  static const String search = '/home/search';
}

/// Provider que expõe o router para o `MaterialApp.router`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _RouterNotifier();

  // Notifica o router via ref.listen, garantindo que authStateProvider
  // já está atualizado quando o redirect roda (evita race condition).
  ref.listen<AsyncValue<AuthUser?>>(
    authStateProvider,
    (_, __) => authNotifier.notify(),
  );
  ref.listen<AsyncValue<AuthUser?>>(
    authControllerProvider,
    (_, __) => authNotifier.notify(),
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,

    // ── Guard de autenticação ────────────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthUser?> authAsync = ref.read(authStateProvider);
      final AsyncValue<AuthUser?> controllerAsync =
          ref.read(authControllerProvider);

      final String location = state.uri.path;

      // Exibe splash enquanto o estado de auth carrega.
      if (authAsync.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // O estado do controller tem prioridade sobre o stream para evitar
      // a race condition no cadastro por e-mail (authStateChanges dispara
      // antes do perfil ser gravado no Firestore).
      final AuthUser? user =
          controllerAsync.valueOrNull ?? authAsync.valueOrNull;

      final bool onAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.username;

      // Não autenticado → /login
      if (user == null) {
        return onAuthRoute ? null : AppRoutes.login;
      }

      // Autenticado mas sem username (novo usuário Google) → /username
      if (!user.hasUsername && location != AppRoutes.username) {
        return AppRoutes.username;
      }

      // Autenticado com username em rota pública → /home
      if (user.hasUsername && (onAuthRoute || location == AppRoutes.splash)) {
        return AppRoutes.home;
      }

      return null; // sem redirecionamento
    },

    routes: <RouteBase>[
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Rotas de autenticação (fora do shell — sem bottom nav) ─────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.username,
        builder: (context, state) {
          // Passa o AuthUser atual para a tela de username.
          // Se por algum motivo for null aqui (improvável após redirect),
          // volta para /login.
          final AuthUser? user = ref.read(authStateProvider).valueOrNull;
          if (user == null) {
            return const LoginPage();
          }
          return UsernamePage(user: user);
        },
      ),

      // ── Shell com bottom nav preservando estado entre as 5 abas (RNF07) ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) =>
            _ScaffoldWithNavBar(navShell: navShell),
        branches: <StatefulShellBranch>[
          // Branch 0 — Início + Mapa (mantém bottom nav no mapa)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'maps',
                    builder: (context, state) => const MapsPage(),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchPage(),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Eventos (lista + detalhes)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.events,
                builder: (context, state) => const EventsListPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        EventDetailPage(eventId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Criar
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.create,
                builder: (context, state) => const CreateEventPage(),
              ),
            ],
          ),
          // Branch 3 — Chat (lista + sala)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ConversationsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ChatRoomPage(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4 — Perfil
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navShell});

  final StatefulNavigationShell navShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navShell.currentIndex,
        // `goBranch` preserva o estado da aba (RNF07): voltar para "Eventos"
        // não recria a página, mantém scroll e detalhes anteriores.
        onTap: (index) => navShell.goBranch(
          index,
          initialLocation: index == navShell.currentIndex,
        ),
      ),
    );
  }
}

class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

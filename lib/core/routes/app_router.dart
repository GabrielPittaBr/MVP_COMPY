import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/username_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/events_list_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/maps/presentation/pages/maps_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'go_router_refresh_stream.dart';

/// Caminhos das principais telas — centralizados para evitar strings espalhadas.
abstract final class AppRoutes {
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
}

/// Provider que expõe o router para o `MaterialApp.router`.
final appRouterProvider = Provider<GoRouter>((ref) {
  // authStateProvider é um StreamProvider; pegamos o stream bruto para o
  // refreshListenable. O router vai chamar redirect sempre que emitir.
  final authNotifier = GoRouterRefreshStream(
    ref.watch(authRepositoryProvider).authState(),
  );

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authNotifier,

    // ── Guard de autenticação ────────────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthUser?> authAsync = ref.read(authStateProvider);

      // Enquanto o estado ainda está carregando, não redireciona.
      if (authAsync.isLoading) return null;

      final AuthUser? user = authAsync.valueOrNull;
      final String location = state.uri.path;

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

      // Autenticado com username mas tentando acessar rota de auth → /home
      if (user.hasUsername && onAuthRoute) {
        return AppRoutes.home;
      }

      return null; // sem redirecionamento
    },

    routes: <RouteBase>[
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

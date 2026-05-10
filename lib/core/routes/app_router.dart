import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/events_list_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/maps/presentation/pages/maps_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../shared/widgets/app_bottom_nav.dart';

/// Caminhos das principais telas — centralizados para evitar strings espalhadas.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String create = '/create';
  static const String chat = '/chat';
  static const String chatRoom = '/chat/:conversationId';
  static const String profile = '/profile';
  static const String maps = '/maps';
}

/// Provider que expõe o router para o `MaterialApp.router`.
final appRouterProvider = Provider<GoRouter>((ref) => _buildRouter());

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      // Rota /maps fica fora do shell pois o mapa é tela cheia
      // (acessada pelo card "Explore locais" da home).
      GoRoute(
        path: AppRoutes.maps,
        builder: (context, state) => const MapsPage(),
      ),

      // Shell com bottom nav preservando estado entre as 5 abas (RNF07).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => _ScaffoldWithNavBar(navShell: navShell),
        branches: <StatefulShellBranch>[
          // Branch 0 — Início
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
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
}

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

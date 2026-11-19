import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/presentation/agenda_page.dart';
import '../../features/agenda/presentation/today_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/free_slots/presentation/free_slots_page.dart';
import '../../features/more/presentation/more_pages.dart';
import '../../features/results/presentation/results_page.dart';
import '../../features/team/presentation/team_page.dart';
import '../../features/venue/presentation/courts_page.dart';
import '../../features/venue/presentation/profile_page.dart';
import '../shell/gestor_shell.dart';

/// Páginas só do Proprietário (e do Gerente, na 2ª versão).
const ownerRoutes = <String>{
  '/resultados',
  '/perfil',
  '/quadras',
  '/equipe',
  '/plano',
};

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/entrar',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      if (session == null) return path == '/entrar' ? null : '/entrar';
      if (path == '/entrar' || path == '/') return '/hoje';
      if (!session.role.managesVenue && ownerRoutes.contains(path)) {
        return '/hoje';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/entrar',
        pageBuilder: (_, _) => const NoTransitionPage(child: LoginPage()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            GestorShell(location: state.uri.path, child: child),
        routes: [
          _page('/hoje', const TodayPage()),
          _page('/agenda', const AgendaPage()),
          _page('/livres', const FreeSlotsPage()),
          _page('/mais', const MorePage()),
          _page('/resultados', const ResultsPage()),
          _page('/perfil', const ProfilePage()),
          _page('/quadras', const CourtsPage()),
          _page('/equipe', const TeamPage()),
          _page('/plano', const PlanPage()),
          _page('/ajuda', const HelpPage()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRoute _page(String path, Widget child) => GoRoute(
  path: path,
  pageBuilder: (_, _) => NoTransitionPage(child: child),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/presentation/today_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../shell/gestor_shell.dart';
import '../shell/page_scaffold.dart';
import '../widgets/common.dart';

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
          _page('/agenda', const _Soon('Agenda')),
          _page('/livres', const _Soon('Horários livres')),
          _page('/mais', const _Soon('Mais')),
          _page('/resultados', const _Soon('Resultados')),
          _page('/perfil', const _Soon('Perfil e tema')),
          _page('/quadras', const _Soon('Quadras e preços')),
          _page('/equipe', const _Soon('Equipe')),
          _page('/plano', const _Soon('Plano')),
          _page('/ajuda', const _Soon('Ajuda')),
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

class _Soon extends StatelessWidget {
  const _Soon(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: title,
    children: const [NoteBox('Esta tela entra na próxima etapa do protótipo.')],
  );
}

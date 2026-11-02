import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/routes/app_router.dart';

/// Hipótese 8 da tarefa 14: a avaliação é uma rota na raiz, fora do
/// `StatefulShellRoute`. Aberta com `push` de dentro de uma aba, ela cobre a
/// tela inteira (sem a barra inferior) e o `pop` volta para onde estava.
void main() {
  testWidgets('a avaliação abre em tela cheia e o pop volta para a aba',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.eventDetailPath('evt_1'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.eventRating,
          builder: (_, state) => Scaffold(
            body: Text('avaliação de ${state.pathParameters['eventId']}'),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: const Text('barra inferior'),
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.events,
                  builder: (_, __) => const Text('lista'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => TextButton(
                        onPressed: () => context.push(
                          AppRoutes.eventRatingPath(
                              state.pathParameters['id']!),
                        ),
                        child: const Text('detalhe'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('barra inferior'), findsOneWidget);

    await tester.tap(find.text('detalhe'));
    await tester.pumpAndSettle();
    expect(find.text('avaliação de evt_1'), findsOneWidget);
    expect(find.text('barra inferior'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('detalhe'), findsOneWidget);
    expect(find.text('barra inferior'), findsOneWidget);
  });
}

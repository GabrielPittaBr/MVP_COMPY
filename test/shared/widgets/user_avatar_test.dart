import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_assets.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('remoção com URL placeholder não solicita imagem de rede',
      (tester) async {
    await _pump(
        tester,
        UserAvatar(
            user: UserSummary(
                id: 'u1',
                name: 'Ana',
                handle: '@ana',
                avatarUrl: AppAssets.avatar('Ana'))));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('URL vazia vira o ícone genérico, sem imagem de rede',
      (tester) async {
    await _pump(
      tester,
      const UserAvatar(
        user: UserSummary(id: 'u1', name: 'Ana', handle: '@ana', avatarUrl: ''),
        radius: 20,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(tester.getSize(find.byType(UserAvatar)), const Size(40, 40));
  });

  testWidgets('usuário ausente também vira o ícone genérico', (tester) async {
    await _pump(tester, const UserAvatar(user: null));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('URL que não é endereço web também vira o ícone genérico',
      (tester) async {
    await _pump(
      tester,
      const UserAvatar(
        user: UserSummary(
          id: 'u1',
          name: 'Ana',
          handle: '@ana',
          avatarUrl: 'javascript:alert(1)',
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
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
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(avatar.radius, 20);
  });

  testWidgets('usuário ausente também vira o ícone genérico', (tester) async {
    await _pump(tester, const UserAvatar(user: null));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isNull,
    );
  });
}

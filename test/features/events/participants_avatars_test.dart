import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/presentation/widgets/participants_avatars.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

void main() {
  testWidgets('participantes sem foto desenham o ícone genérico sem quebrar',
      (tester) async {
    const participants = <UserSummary>[
      UserSummary(id: 'u1', name: 'Ana', handle: '@ana', avatarUrl: ''),
      UserSummary(id: 'u2', name: 'Bruno', handle: '@bruno', avatarUrl: ''),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ParticipantsAvatars(participants: participants)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(UserAvatar), findsNWidgets(2));
    expect(find.byIcon(Icons.person), findsNWidgets(2));
  });

  testWidgets('mostra no máximo maxVisible avatares', (tester) async {
    final participants = List<UserSummary>.generate(
      5,
      (i) => UserSummary(id: 'u$i', name: 'P$i', handle: '@p$i', avatarUrl: ''),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipantsAvatars(participants: participants, maxVisible: 3),
        ),
      ),
    );

    expect(find.byType(UserAvatar), findsNWidgets(3));
  });
}

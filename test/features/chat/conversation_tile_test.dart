import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/presentation/widgets/conversation_tile.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

const _peer = UserSummary(
  id: 'peer',
  name: 'Ana Souza',
  handle: '@ana',
  avatarUrl: '',
);

Conversation _conversation({
  required DateTime sentAt,
  String name = 'Ana Souza',
  String message = 'Vamos jogar amanhã?',
  int unread = 0,
}) =>
    Conversation(
      id: 'c1',
      peer: UserSummary(
        id: _peer.id,
        name: name,
        handle: _peer.handle,
        avatarUrl: _peer.avatarUrl,
      ),
      lastMessage: message,
      unreadCount: unread,
      lastMessageAt: sentAt,
    );

Future<void> _pumpTile(
  WidgetTester tester,
  Conversation conversation, {
  required DateTime now,
  VoidCallback? onTap,
  Size size = const Size(390, 180),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        publicUserSummaryProvider.overrideWith((ref, uid) => Stream.value(null))
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ConversationTile(
            conversation: conversation,
            now: now,
            onTap: onTap ?? () {},
          ),
        ),
      )));
}

void main() {
  testWidgets('hoje mostra horário real convertido para hora local',
      (tester) async {
    final now = DateTime(2026, 10, 26, 16);
    final sentAt = DateTime(2026, 10, 26, 14, 5).toUtc();
    await _pumpTile(tester, _conversation(sentAt: sentAt), now: now);
    expect(find.text('14:05'), findsOneWidget);
    expect(find.text(AppStrings.chatToday), findsNothing);
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('ontem usa dia do calendário mesmo perto da meia-noite',
      (tester) async {
    final now = DateTime(2026, 10, 26, 0, 15);
    await _pumpTile(
      tester,
      _conversation(sentAt: DateTime(2026, 10, 25, 23, 50)),
      now: now,
    );
    expect(find.text(AppStrings.chatYesterday), findsOneWidget);
  });

  testWidgets('mensagem antiga mostra data curta brasileira', (tester) async {
    await _pumpTile(
      tester,
      _conversation(sentAt: DateTime(2026, 10, 24, 18, 45)),
      now: DateTime(2026, 10, 26),
    );
    expect(find.text('24/10/26'), findsOneWidget);
  });

  testWidgets('não lidas recebem destaque e badge; lidas não', (tester) async {
    final now = DateTime(2026, 10, 26, 16);
    await _pumpTile(
      tester,
      _conversation(sentAt: now, unread: 3),
      now: now,
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Vamos jogar amanhã?'), findsOneWidget);
    final unreadName = tester.widget<Text>(find.text(_peer.name));
    expect(unreadName.style?.fontWeight, FontWeight.w700);

    await _pumpTile(
      tester,
      _conversation(sentAt: now),
      now: now,
    );
    expect(find.text('3'), findsNothing);
    final readName = tester.widget<Text>(find.text(_peer.name));
    expect(readName.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('nome e prévia grandes cabem no celular pequeno e toque funciona',
      (tester) async {
    var taps = 0;
    final now = DateTime(2026, 10, 26, 16);
    await _pumpTile(
      tester,
      _conversation(
        sentAt: now,
        unread: 125,
        name: 'Nome muito comprido de uma pessoa que pratica vários esportes',
        message: 'Mensagem longa para combinar um jogo com muitas informações',
      ),
      now: now,
      onTap: () => taps++,
      size: const Size(280, 180),
    );
    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('conversation-c1')));
    expect(taps, 1);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/presentation/models/chat_timeline.dart';

void main() {
  Message at(String id, DateTime sentAt) => Message(
        id: id,
        conversationId: 'c_douglas',
        senderId: 'uid_joao',
        text: id,
        sentAt: sentAt,
      );

  List<String> shape(List<ChatTimelineItem> items) => items
      .map((item) => switch (item) {
            ChatDaySeparator(:final day) => 'dia ${day.day}/${day.month}',
            ChatMessageItem(:final message) => message.id,
          })
      .toList();

  group('buildChatTimeline', () {
    test('conversa vazia não produz separador algum', () {
      expect(buildChatTimeline(const <Message>[]), isEmpty);
    });

    test('mensagens do mesmo dia ficam sob um único separador', () {
      final items = buildChatTimeline(<Message>[
        at('m1', DateTime(2026, 8, 9, 9)),
        at('m2', DateTime(2026, 8, 9, 10)),
        at('m3', DateTime(2026, 8, 9, 23, 59)),
      ]);

      expect(shape(items), <String>['dia 9/8', 'm1', 'm2', 'm3']);
    });

    test('cada virada de dia abre um separador novo', () {
      final items = buildChatTimeline(<Message>[
        at('m1', DateTime(2026, 8, 7, 20)),
        at('m2', DateTime(2026, 8, 8, 8)),
        at('m3', DateTime(2026, 8, 8, 21)),
        at('m4', DateTime(2026, 8, 9, 7)),
      ]);

      expect(shape(items), <String>[
        'dia 7/8',
        'm1',
        'dia 8/8',
        'm2',
        'm3',
        'dia 9/8',
        'm4',
      ]);
    });

    test('o separador carrega a data da mensagem, não a de hoje', () {
      final items = buildChatTimeline(<Message>[
        at('m1', DateTime(2025, 12, 31, 22)),
      ]);

      final separator = items.first as ChatDaySeparator;
      expect(separator.day, DateTime(2025, 12, 31));
    });
  });
}

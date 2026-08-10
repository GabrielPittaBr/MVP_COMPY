import '../../../../core/utils/day_label.dart';
import '../../domain/entities/message.dart';

/// Item da lista da sala de chat: ou um separador de dia, ou uma mensagem.
///
/// A sala renderiza uma lista só, então as duas coisas precisam caber no mesmo
/// índice — daí o tipo selado em vez de dois `ListView` aninhados.
sealed class ChatTimelineItem {
  const ChatTimelineItem();
}

class ChatDaySeparator extends ChatTimelineItem {
  const ChatDaySeparator(this.day);

  /// Meia-noite do dia representado — a hora é descartada de propósito.
  final DateTime day;
}

class ChatMessageItem extends ChatTimelineItem {
  const ChatMessageItem(this.message);

  final Message message;
}

/// Intercala separadores de dia entre [messages], que já vêm ordenadas da
/// mais antiga para a mais recente.
///
/// Antes existia um único chip fixo escrito "Hoje" no topo da sala,
/// independente da data das mensagens.
List<ChatTimelineItem> buildChatTimeline(List<Message> messages) {
  final items = <ChatTimelineItem>[];
  DateTime? currentDay;

  for (final message in messages) {
    if (currentDay == null || !DayLabel.isSameDay(currentDay, message.sentAt)) {
      currentDay = DateTime(
        message.sentAt.year,
        message.sentAt.month,
        message.sentAt.day,
      );
      items.add(ChatDaySeparator(currentDay));
    }
    items.add(ChatMessageItem(message));
  }

  return items;
}

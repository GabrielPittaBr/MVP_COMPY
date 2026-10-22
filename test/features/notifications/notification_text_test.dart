import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/utils/relative_time.dart';
import 'package:mvp_compy/features/notifications/domain/entities/app_notification.dart';
import 'package:mvp_compy/features/notifications/domain/notification_text.dart';

AppNotification _notificacao({bool automatico = false}) => AppNotification(
      id: 'eventEnded_evt_1',
      type: AppNotificationType.eventEnded,
      eventId: 'evt_1',
      eventTitle: 'Peladinha de Quinta',
      sport: 'futebol',
      creatorId: 'u_dono',
      endedAutomatically: automatico,
      createdAt: DateTime(2026, 10, 21, 20),
    );

void main() {
  group('NotificationText', () {
    test('participante: "{título} terminou" e o convite completo', () {
      final n = _notificacao();
      expect(
          NotificationText.title(n, 'u_bruno'), 'Peladinha de Quinta terminou');
      expect(
        NotificationText.body(n, 'u_bruno'),
        'Como foi? Avalie o evento, o local e quem jogou com você.',
      );
    });

    test('criador com encerramento manual: sem o evento no convite (D14)', () {
      final n = _notificacao();
      expect(
          NotificationText.title(n, 'u_dono'), 'Peladinha de Quinta terminou');
      expect(
        NotificationText.body(n, 'u_dono'),
        'Como foi? Avalie o local e quem jogou com você.',
      );
    });

    test('criador com encerramento automático: o aviso de que o app encerrou',
        () {
      final n = _notificacao(automatico: true);
      expect(
        NotificationText.title(n, 'u_dono'),
        'Seu evento foi encerrado automaticamente',
      );
      expect(
        NotificationText.body(n, 'u_dono'),
        'Peladinha de Quinta passou 1h do horário previsto. '
        'Avalie o local e os participantes.',
      );
    });

    test('participante de evento encerrado automaticamente lê o texto comum',
        () {
      final n = _notificacao(automatico: true);
      expect(
          NotificationText.title(n, 'u_bruno'), 'Peladinha de Quinta terminou');
    });
  });

  group('RelativeTime', () {
    final agora = DateTime(2026, 10, 21, 20, 30);

    test('minutos e horas no mesmo dia', () {
      expect(
          RelativeTime.of(agora.subtract(const Duration(seconds: 20)),
              now: agora),
          'agora');
      expect(
          RelativeTime.of(agora.subtract(const Duration(minutes: 12)),
              now: agora),
          'há 12 min');
      expect(
          RelativeTime.of(agora.subtract(const Duration(hours: 2)), now: agora),
          'há 2 h');
    });

    test('"ontem" e "há X dias" pelo calendário', () {
      expect(
          RelativeTime.of(DateTime(2026, 10, 20, 23, 50),
              now: DateTime(2026, 10, 21, 0, 10)),
          'ontem');
      expect(RelativeTime.of(DateTime(2026, 10, 20, 8), now: agora), 'ontem');
      expect(
          RelativeTime.of(DateTime(2026, 10, 18, 22), now: agora), 'há 3 dias');
    });
  });
}

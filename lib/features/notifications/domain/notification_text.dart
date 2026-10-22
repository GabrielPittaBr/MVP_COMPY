import '../../../core/constants/app_strings.dart';
import 'entities/app_notification.dart';

/// Título e corpo de uma notificação, montados para quem a lê.
///
/// - Participante: "{título} terminou" / avalie o evento, o local e quem
///   jogou.
/// - Criador que encerrou à mão: o mesmo título, sem o evento no convite
///   (D14: ele não avalia o próprio evento).
/// - Criador com encerramento automático: o aviso de que o app encerrou.
///
/// O título "{título} terminou" substituiu o "Como foi o {título}?" do plano
/// no design aprovado: o "o" errava o gênero com títulos femininos.
abstract final class NotificationText {
  static String title(AppNotification notification, String viewerId) {
    if (_isAutoEndedForCreator(notification, viewerId)) {
      return AppStrings.notificationAutoEndedTitle;
    }
    return AppStrings.notificationEventEndedTitle(notification.eventTitle);
  }

  static String body(AppNotification notification, String viewerId) {
    if (_isAutoEndedForCreator(notification, viewerId)) {
      return AppStrings.notificationAutoEndedBody(notification.eventTitle);
    }
    return notification.creatorId == viewerId
        ? AppStrings.notificationEventEndedBodyCreator
        : AppStrings.notificationEventEndedBodyParticipant;
  }

  static bool _isAutoEndedForCreator(AppNotification n, String viewerId) =>
      n.endedAutomatically && n.creatorId == viewerId;
}

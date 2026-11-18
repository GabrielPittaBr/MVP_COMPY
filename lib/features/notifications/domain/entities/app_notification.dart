import 'package:equatable/equatable.dart';

/// Tipos de notificação in-app. `eventCancelled` avisa os participantes de
/// que o evento foi apagado: pela exclusão da conta de quem organizava
/// (chore/lgpd) ou pela Exclusão pelo Organizador (#37). O modelo aceita
/// outros tipos no futuro sem quebrar a leitura.
enum AppNotificationType { eventEnded, eventCancelled }

/// Notificação da central (`users/{uid}/notifications/{id}`, tarefa 14).
///
/// O texto não é gravado: o app monta título e corpo a partir do tipo e dos
/// campos (ver `NotificationText`), o que deixa a central pronta para i18n.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.eventId,
    required this.eventTitle,
    required this.sport,
    required this.creatorId,
    required this.endedAutomatically,
    required this.createdAt,
    this.readAt,
    this.completedAt,
    this.cancelledByOrganizer = false,
    this.reason,
  });

  final String id;
  final AppNotificationType type;
  final String eventId;
  final String eventTitle;

  /// Nome do enum `Sport` gravado no evento.
  final String sport;
  final String creatorId;
  final bool endedAutomatically;
  final DateTime createdAt;

  /// Nulo = não lida.
  final DateTime? readAt;

  /// Preenchido pela callable quando a pessoa avalia ("Avaliado ✓").
  final DateTime? completedAt;

  /// `eventCancelled` pela Exclusão pelo Organizador (`cancelledBy:
  /// 'organizer'`). Falso é a exclusão da conta, como nos avisos antigos.
  final bool cancelledByOrganizer;

  /// Motivo opcional da Exclusão pelo Organizador.
  final String? reason;

  bool get isRead => readAt != null;
  bool get isCompleted => completedAt != null;

  AppNotification copyWith({DateTime? readAt, DateTime? completedAt}) =>
      AppNotification(
        id: id,
        type: type,
        eventId: eventId,
        eventTitle: eventTitle,
        sport: sport,
        creatorId: creatorId,
        endedAutomatically: endedAutomatically,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        completedAt: completedAt ?? this.completedAt,
        cancelledByOrganizer: cancelledByOrganizer,
        reason: reason,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        type,
        eventId,
        eventTitle,
        sport,
        creatorId,
        endedAutomatically,
        createdAt,
        readAt,
        completedAt,
        cancelledByOrganizer,
        reason,
      ];
}

/// Id determinístico da notificação de evento encerrado, o mesmo do gatilho
/// `onEventEnded` (functions/src/event_notifications.ts).
String eventEndedNotificationId(String eventId) => 'eventEnded_$eventId';

/// Id determinístico do aviso de evento cancelado, o mesmo das Functions
/// (`eventCancelledNotificationId` em functions/src/account_cleanup.ts).
String eventCancelledNotificationId(String eventId) => 'eventCancelled_$eventId';

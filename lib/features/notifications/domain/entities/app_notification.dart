import 'package:equatable/equatable.dart';

/// Tipos de notificação in-app. Só `eventEnded` existe por enquanto; o
/// modelo aceita outros no futuro sem quebrar a leitura.
enum AppNotificationType { eventEnded }

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
      ];
}

/// Id determinístico da notificação de evento encerrado, o mesmo do gatilho
/// `onEventEnded` (functions/src/event_notifications.ts).
String eventEndedNotificationId(String eventId) => 'eventEnded_$eventId';

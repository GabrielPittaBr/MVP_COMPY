import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_strings.dart';

/// Motivos de denúncia (chore/lgpd). O nome do enum é o que vai para
/// `reports/{id}.reason`, a mesma lista de `firestore.rules`.
enum ReportReason {
  harassment,
  hate,
  sexual,
  childSafety,
  violence,
  spam,
  fake,
  other;

  String get label => switch (this) {
        ReportReason.harassment => AppStrings.reportReasonHarassment,
        ReportReason.hate => AppStrings.reportReasonHate,
        ReportReason.sexual => AppStrings.reportReasonSexual,
        ReportReason.childSafety => AppStrings.reportReasonChildSafety,
        ReportReason.violence => AppStrings.reportReasonViolence,
        ReportReason.spam => AppStrings.reportReasonSpam,
        ReportReason.fake => AppStrings.reportReasonFake,
        ReportReason.other => AppStrings.reportReasonOther,
      };

  /// 0 vai para o topo da fila do painel (ECA Digital, arts. 27–29).
  int get priority => this == ReportReason.childSafety ? 0 : 1;
}

enum ReportTargetType { user, event, message }

/// O que está sendo denunciado. [targetUid] é o dono do conteúdo: o próprio
/// perfil, o criador do evento ou quem enviou a mensagem.
class ReportTarget extends Equatable {
  const ReportTarget.user(String uid)
      : type = ReportTargetType.user,
        targetId = uid,
        targetUid = uid,
        conversationId = null,
        messageText = null;

  const ReportTarget.event({required String eventId, required String creatorId})
      : type = ReportTargetType.event,
        targetId = eventId,
        targetUid = creatorId,
        conversationId = null,
        messageText = null;

  /// A cópia do texto é conferida pelas regras com a mensagem original.
  const ReportTarget.message({
    required String messageId,
    required String this.conversationId,
    required String senderId,
    required String text,
  })  : type = ReportTargetType.message,
        targetId = messageId,
        targetUid = senderId,
        messageText = text;

  final ReportTargetType type;
  final String targetId;
  final String targetUid;
  final String? conversationId;
  final String? messageText;

  String get title => switch (type) {
        ReportTargetType.user => AppStrings.reportUserTitle,
        ReportTargetType.event => AppStrings.reportEventTitle,
        ReportTargetType.message => AppStrings.reportMessageTitle,
      };

  @override
  List<Object?> get props =>
      <Object?>[type, targetId, targetUid, conversationId, messageText];
}

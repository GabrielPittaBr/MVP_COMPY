import '../../../../shared/models/user_summary.dart';
import '../repositories/chat_repository.dart';

/// Abre a conversa 1:1 com alguém, criando-a se ainda não existir.
///
/// Devolve o id da conversa — o mesmo par de pessoas sempre leva ao mesmo id,
/// então chamar duas vezes não produz duas conversas.
class OpenConversation {
  const OpenConversation(this._repository);
  final ChatRepository _repository;

  Future<String> call({
    required UserSummary me,
    required UserSummary peer,
  }) =>
      _repository.openConversationWith(me: me, peer: peer);
}

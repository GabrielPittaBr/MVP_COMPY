/// As regras recusaram a conversa (chore/lgpd): uma das pessoas bloqueou a
/// outra, ou uma delas tem 16 ou 17 anos e as duas não são amigas (`canTalk`
/// em `firestore.rules`).
class ConversationNotAllowedException implements Exception {
  const ConversationNotAllowedException();
  @override
  String toString() => 'ConversationNotAllowedException';
}

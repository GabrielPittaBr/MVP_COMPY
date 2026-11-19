import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../venue/domain/venue.dart';

class Session {
  const Session(this.name, this.role);

  final String name;
  final Role role;

  String get firstName => name.split(' ').first;
}

/// Quem está no painel. Na demonstração, a entrada não confere senha: basta
/// escolher o papel.
final sessionProvider = NotifierProvider<SessionController, Session?>(
  SessionController.new,
);

class SessionController extends Notifier<Session?> {
  @override
  Session? build() => null;

  void signIn(Role role) => state = role == Role.proprietario
      ? const Session('Carlos Mendes', Role.proprietario)
      : const Session('Ana Ribeiro', Role.atendente);

  void signOut() => state = null;
}

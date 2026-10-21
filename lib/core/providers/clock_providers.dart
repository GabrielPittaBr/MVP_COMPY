import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio do app. Telas, repositórios e testes leem o "agora" daqui, e não
/// de `DateTime.now()`, para que o status do evento (tarefa 14) possa ser
/// testado com um instante fixo.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// De quanto em quanto tempo [nowProvider] emite um novo "agora".
const Duration kNowRefreshInterval = Duration(seconds: 30);

/// "Agora" que se atualiza sozinho, para a tela trocar de "agendado" para
/// "acontecendo" (e daí para "encerrado") sem o usuário recarregar.
///
/// Nos testes de widget, sobrescreva com um valor fixo: um timer periódico
/// pendente no fim do teste derruba o `testWidgets`.
final nowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return _ticks(clock);
});

Stream<DateTime> _ticks(DateTime Function() clock) async* {
  yield clock();
  yield* Stream<DateTime>.periodic(kNowRefreshInterval, (_) => clock());
}

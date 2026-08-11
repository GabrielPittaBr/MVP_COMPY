import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/event.dart';
import 'events_providers.dart';

/// Termo digitado no campo de busca. `autoDispose` zera o estado quando
/// a tela de busca é fechada.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Resultados da busca por nome do evento ou modalidade esportiva.
///
/// Debounce de 500ms: cada tecla recria este provider (ele observa
/// [searchQueryProvider]); se outra tecla chegar antes do delay terminar,
/// a versão anterior é descartada e a consulta ao Firestore nem chega a
/// ser disparada.
final searchResultsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return const <Event>[];

  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (disposed) return const <Event>[];

  return ref.read(eventsRepositoryProvider).search(query);
});

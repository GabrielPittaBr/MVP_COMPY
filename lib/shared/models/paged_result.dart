/// Página de resultados de uma consulta paginada.
///
/// [cursor] é opaco para o domínio: no Firestore é o último
/// `DocumentSnapshot` da página (usado com `startAfterDocument`); no modo
/// mock é o offset da lista. Repassar o cursor da página anterior busca a
/// próxima.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<T> items;
  final bool hasMore;
  final Object? cursor;

  static PagedResult<T> empty<T>() =>
      PagedResult<T>(items: List<T>.empty(), hasMore: false);
}

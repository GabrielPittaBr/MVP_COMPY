import '../../../../shared/models/user_summary.dart';
import '../repositories/profile_repository.dart';

/// Busca usuários pelo começo do handle.
///
/// Abaixo de [minPrefixLength] caracteres não consulta nada: uma letra só
/// devolveria meia base e cobraria leitura por isso.
class SearchUsers {
  const SearchUsers(this._repository);
  final ProfileRepository _repository;

  static const int minPrefixLength = 2;

  Future<List<UserSummary>> call(
    String handlePrefix, {
    String? excludeUid,
    int limit = 20,
  }) {
    final prefix = handlePrefix.trim().replaceFirst('@', '');
    if (prefix.length < minPrefixLength) {
      return Future<List<UserSummary>>.value(const <UserSummary>[]);
    }
    return _repository.searchByHandle(
      prefix,
      excludeUid: excludeUid,
      limit: limit,
    );
  }
}

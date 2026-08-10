import '../../../../shared/models/user_summary.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile(String uid);

  /// Usuários cujo handle começa por [handlePrefix] (digitado sem o `@`).
  ///
  /// [excludeUid] tira o próprio usuário do resultado — ninguém abre conversa
  /// consigo mesmo.
  Future<List<UserSummary>> searchByHandle(
    String handlePrefix, {
    String? excludeUid,
    int limit,
  });
}

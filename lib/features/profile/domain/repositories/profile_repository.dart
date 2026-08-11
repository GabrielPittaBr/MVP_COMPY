import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile(String uid);

  /// Registra a escolha de esportes favoritos de [uid].
  ///
  /// Lista vazia é escolha válida — é o que o "pular" do onboarding grava. O
  /// que marca o onboarding como concluído é o campo passar a existir, não a
  /// lista ter itens.
  Future<void> updateFavoriteSports(String uid, List<Sport> sports);

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

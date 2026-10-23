import 'dart:typed_data';

import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile(String uid);

  /// Lê somente os campos públicos de `users/{uid}`. Ausência não é mock.
  Future<UserProfile?> getPublicProfile(String uid);

  /// Registra a escolha de esportes favoritos de [uid].
  ///
  /// Lista vazia é escolha válida — é o que o "pular" do onboarding grava. O
  /// que marca o onboarding como concluído é o campo passar a existir, não a
  /// lista ter itens.
  Future<void> updateFavoriteSports(String uid, List<Sport> sports);

  /// Atualiza os campos públicos e sincroniza o nome no Firebase Auth.
  Future<void> updateDetails(String uid,
      {required String name, required String bio});

  /// Troca a foto do perfil de [uid] por [jpeg] (já recortado e reduzido).
  ///
  /// `null` remove a foto: o perfil volta para a inicial de [name]. A foto
  /// anterior continua valendo nos eventos e conversas que já a copiaram.
  Future<void> updateAvatar(String uid, {required String name, Uint8List? jpeg});

  /// Usuários cujo handle começa por [handlePrefix] (digitado sem o `@`).
  ///
  /// [excludeUid] tira o próprio usuário do resultado — ninguém abre conversa
  /// consigo mesmo.
  Future<List<UserSummary>> searchByHandle(
    String handlePrefix, {
    String? excludeUid,
    int limit,
  });

  /// Usuários cujo nome normalizado começa por [namePrefix].
  Future<List<UserSummary>> searchByName(
    String namePrefix, {
    String? excludeUid,
    int limit,
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/mock_profile.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/search_users.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ProfileRemoteDataSource(FirebaseFirestore.instance) : null,
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);

final getProfileProvider = Provider<GetProfile>(
  (ref) => GetProfile(ref.watch(profileRepositoryProvider)),
);

final searchUsersProvider = Provider<SearchUsers>(
  (ref) => SearchUsers(ref.watch(profileRepositoryProvider)),
);

/// Resultado da busca por handle, com debounce.
///
/// A família é chaveada pelo texto digitado: cada tecla cria um provider novo
/// e descarta o anterior, e o descarte cancela a espera antes de a consulta
/// sair. Só o texto que ficar parado por [_searchDebounce] chega ao Firestore.
final userSearchProvider =
    FutureProvider.autoDispose.family<List<UserSummary>, String>(
  (ref, query) async {
    if (query.trim().replaceFirst('@', '').length < SearchUsers.minPrefixLength) {
      return const <UserSummary>[];
    }

    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_searchDebounce);
    if (cancelled) return const <UserSummary>[];

    return ref.watch(searchUsersProvider).call(
          query,
          excludeUid: ref.watch(authStateProvider).valueOrNull?.uid,
        );
  },
);

const Duration _searchDebounce = Duration(milliseconds: 350);

final currentProfileProvider = FutureProvider<UserProfile>((ref) {
  // Sem Firebase não há uid, e exigir um deixaria o app mockado sem
  // identidade — era o que fazia "Nova conversa" terminar sempre em erro
  // com `kUseFirebaseRepos = false`.
  if (!kUseFirebaseRepos) return MockProfile.current;

  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) throw Exception('Usuário não autenticado');
  return ref.watch(getProfileProvider).call(uid);
});

/// Grava a escolha de esportes favoritos.
///
/// Estado só para a tela saber quando desabilitar o botão e quando reclamar:
/// `null` = ocioso, loading = gravando, error = falhou.
/// Não é `autoDispose` de propósito: gravar dispara o redirecionamento do
/// guard, que desmonta a tela — e um notifier descartado no meio do `save()`
/// estoura ao receber o estado final.
class FavoriteSportsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Devolve `true` quando a escolha foi de fato gravada.
  ///
  /// Lista vazia é escolha válida — é o que o "pular" do onboarding grava.
  Future<bool> save(List<Sport> sports) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      final String uid = await _requireUid();
      await ref.read(profileRepositoryProvider).updateFavoriteSports(uid, sports);
      // O perfil (e o carrossel da Home, que bebe dele) precisa refletir a
      // escolha sem esperar o app reabrir.
      ref.invalidate(currentProfileProvider);
      // E o guard do router precisa saber que o onboarding acabou, senão
      // devolve o usuário para a tela que ele acabou de concluir.
      ref.read(authControllerProvider.notifier).markFavoriteSportsChosen();
    });

    final AsyncValue<void> result = state;
    if (result.hasError) {
      debugPrint('[FavoriteSports] falha ao gravar: ${result.error}');
      debugPrintStack(stackTrace: result.stackTrace);
    }
    return !result.hasError;
  }

  /// Uid de quem está gravando, na mesma ordem de prioridade que o guard usa.
  ///
  /// O controller vem primeiro, e isso é o conserto de um bug real: quem
  /// acabou de se cadastrar chega aqui com um `AuthUser` perfeitamente bom no
  /// controller enquanto o stream pode estar **em erro** — basta a releitura
  /// de `users/{uid}` disparada por `updateDisplayName` ter estourado o
  /// timeout. A versão anterior lia só `authStateProvider.future`, que
  /// repropaga esse erro, e o cadastro terminava em "não foi possível salvar
  /// seus esportes" com a rede inteira funcionando.
  ///
  /// Esperar a primeira emissão fica como último recurso: só quando não há
  /// valor nenhum em mãos, o que acontece se o stream acabou de ser ligado.
  Future<String> _requireUid() async {
    AuthUser? user = ref.read(authControllerProvider).valueOrNull ??
        ref.read(authStateProvider).valueOrNull;
    user ??= await ref.read(authStateProvider.future);

    final String? uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      if (!kUseFirebaseRepos) return '';
      throw StateError('Sem usuário autenticado para gravar os esportes');
    }
    return uid;
  }
}

final favoriteSportsControllerProvider =
    AsyncNotifierProvider<FavoriteSportsController, void>(
  FavoriteSportsController.new,
);

/// Identidade pública ([UserSummary]) do usuário logado — usada para
/// registrar participação em eventos e preencher o criador na criação.
final currentUserSummaryProvider = FutureProvider<UserSummary>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile.summary;
});

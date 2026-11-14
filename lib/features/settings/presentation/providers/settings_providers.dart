import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/firebase_service.dart';
import '../../data/datasources/data_export_remote_datasource.dart';
import '../../data/repositories/data_export_repository_impl.dart';
import '../../domain/repositories/data_export_repository.dart';
import '../../domain/usecases/export_my_data.dart';

final dataExportRemoteProvider = Provider<DataExportRemoteDataSource?>(
  (ref) => kUseFirebaseRepos && firebaseEnabled
      ? DataExportRemoteDataSource(FirebaseFunctions.instanceFor(region: kFunctionsRegion))
      : null,
);

final dataExportRepositoryProvider = Provider<DataExportRepository>(
  (ref) => DataExportRepositoryImpl(ref.watch(dataExportRemoteProvider)),
);

final exportMyDataProvider =
    Provider((ref) => ExportMyData(ref.watch(dataExportRepositoryProvider)));

/// Entrega o JSON pelo compartilhamento do Android: a pessoa escolhe salvar
/// em Arquivos ou no Drive, ou mandar por e-mail. Trocável nos testes.
typedef ShareDataFile = Future<void> Function(String json);

final shareDataFileProvider = Provider<ShareDataFile>(
  (ref) => (String json) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: 'meus-dados-compy.json',
          ),
        ],
        fileNameOverrides: const <String>['meus-dados-compy.json'],
        subject: AppStrings.settingsDownloadShareSubject,
      ),
    );
  },
);

/// "Baixar meus dados": gera a cópia e abre o compartilhamento.
class DataExportController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> run() async {
    if (state.isLoading) return false;
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      final String json = await ref.read(exportMyDataProvider).call();
      await ref.read(shareDataFileProvider)(json);
    });
    return !state.hasError;
  }
}

final dataExportControllerProvider =
    AutoDisposeAsyncNotifierProvider<DataExportController, void>(DataExportController.new);

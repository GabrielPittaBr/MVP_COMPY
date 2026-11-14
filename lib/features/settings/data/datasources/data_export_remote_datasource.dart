import 'package:cloud_functions/cloud_functions.dart';

/// Callable `exportMyData` (functions/src/data_export.ts), que monta o JSON
/// no servidor: ela lê coleções que o app sozinho não alcança, como as
/// avaliações que a pessoa fez.
class DataExportRemoteDataSource {
  const DataExportRemoteDataSource(this._functions);
  final FirebaseFunctions _functions;

  Future<Object?> exportMyData() async {
    final HttpsCallableResult<Object?> result = await _functions
        .httpsCallable(
          'exportMyData',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call<Object?>();
    return result.data;
  }
}

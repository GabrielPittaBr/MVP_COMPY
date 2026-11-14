import 'dart:convert';

import '../../domain/repositories/data_export_repository.dart';
import '../datasources/data_export_remote_datasource.dart';

class DataExportRepositoryImpl implements DataExportRepository {
  const DataExportRepositoryImpl(this._remote, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DataExportRemoteDataSource? _remote;
  final DateTime Function() _clock;

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<String> exportMyData() async {
    final DataExportRemoteDataSource? remote = _remote;
    if (remote == null) {
      // Modo mock: não há servidor para montar a cópia.
      return _encoder.convert(<String, Object?>{
        'formato': 'compy-dados-v1',
        'geradoEm': _clock().toUtc().toIso8601String(),
        'aviso': 'Modo de demonstração: nenhum dado real é guardado.',
      });
    }
    return _encoder.convert(await remote.exportMyData());
  }
}

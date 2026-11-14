import '../repositories/data_export_repository.dart';

class ExportMyData {
  const ExportMyData(this._repository);
  final DataExportRepository _repository;

  Future<String> call() => _repository.exportMyData();
}

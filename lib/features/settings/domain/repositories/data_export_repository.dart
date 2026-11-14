/// "Baixar meus dados" (chore/lgpd; LGPD art. 18, II e V).
abstract interface class DataExportRepository {
  /// Tudo o que o COMPY guarda sobre o usuário logado, já em JSON formatado.
  Future<String> exportMyData();
}

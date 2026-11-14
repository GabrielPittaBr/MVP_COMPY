/// Endereços públicos e contato da LGPD (chore/lgpd).
///
/// As páginas moram em `site/` e são publicadas no Firebase Hosting
/// (`compy-tcc.web.app`). A Play Store exige o link da política dentro do app e
/// no Console, e o link de exclusão de conta no Console.
abstract final class AppLinks {
  static const String site = 'https://compy-tcc.web.app';
  static const String privacyPolicy = '$site/privacidade';
  static const String terms = '$site/termos';
  static const String deleteAccount = '$site/excluir-conta';
  static const String safety = '$site/seguranca';

  /// Canal do encarregado (LGPD art. 41) e contato de segurança infantil.
  static const String privacyEmail = 'contato.compy@gmail.com';

  /// Versão dos Termos de Uso e da Política de Privacidade, a mesma data que
  /// aparece no topo das páginas. Mudou o texto de forma relevante, muda aqui:
  /// o guard do router leva todo mundo para um novo aceite.
  static const String legalVersion = '2026-11-14';
}

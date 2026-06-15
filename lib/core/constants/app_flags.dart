/// Flags globais da aplicação.
///
/// [kUseFirebaseRepos] controla se os repositórios consomem Firestore real
/// ou retornam dados mockados em memória. Default `false` permite rodar o
/// app sem `firebase_options.dart` configurado (`flutterfire configure`).
abstract final class AppFlags {
  static const bool useFirebaseRepos = true;
}

/// Atalho de leitura para evitar `AppFlags.useFirebaseRepos` em todo lugar.
const bool kUseFirebaseRepos = AppFlags.useFirebaseRepos;

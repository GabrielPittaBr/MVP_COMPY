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

/// Aponta Auth e Firestore para os emuladores locais
/// (`firebase emulators:start --only auth,firestore`). Só para testar sem
/// tocar o projeto real — ligado com
/// `flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true`.
/// O host é `localhost`, então serve para web e desktop; no emulador do
/// Android seria `10.0.2.2`.
const bool kUseFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS');

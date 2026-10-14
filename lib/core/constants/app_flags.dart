/// Flags globais da aplicação.
///
/// [kUseFirebaseRepos] controla exclusivamente se os repositórios de domínio
/// consomem o Firestore real ou retornam dados mockados em memória.
///
/// Firebase Core e Firebase Authentication não dependem desta flag: ambos são
/// inicializados no bootstrap. Mantê-la em `true` é o modo normal do COMPY;
/// mocks só devem ser usados em desenvolvimento/testes de repositórios.
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

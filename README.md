# COMPY — MVP

App móvel para conectar praticantes de esportes em **Taquara/RS** (TCC).
Stack: **Flutter + Riverpod + GoRouter + Firebase (scaffold) + flutter_map (OSM)**.
Arquitetura: **Clean Architecture Feature-First**.

## Setup inicial

Pré-requisitos: Flutter SDK ≥ 3.22, Dart ≥ 3.4, Android Studio / Xcode.

```bash
# 1. Gerar pastas nativas (android/ios) sem sobrescrever lib/ e pubspec
flutter create . --project-name mvp_compy --platforms android,ios

# 2. Instalar dependências
flutter pub get

# 3. Rodar
flutter run
```

## Firebase (opcional, para chat real-time real)

Por padrão `kUseFirebaseRepos = false` — os repositórios servem dados mockados em memória.
Para ligar Firestore real:

```bash
dart pub global activate flutterfire_cli
flutterfire configure   # gera lib/firebase_options.dart
```

E em `lib/core/constants/app_flags.dart` setar `kUseFirebaseRepos = true`.

## Estrutura

```
lib/
├── core/        # theme, routes, services, constants
├── features/    # home, maps, events, profile, chat (cada uma com data/domain/presentation)
└── shared/      # widgets e modelos comuns
```

## Mapeamento Tela ↔ Requisitos

| Tela | RF/RN | Página |
|---|---|---|
| Home | RF07, RF11 | `features/home/presentation/pages/home_page.dart` |
| Mapa | RF04, RN-04 | `features/maps/presentation/pages/maps_page.dart` |
| Evento | RF07, RN-05 | `features/events/presentation/pages/event_detail_page.dart` |
| Perfil | RF01, RF08, RF10 | `features/profile/presentation/pages/profile_page.dart` |
| Chat | RF05, RF14 | `features/chat/presentation/pages/conversations_page.dart` |

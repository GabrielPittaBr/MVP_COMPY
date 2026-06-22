# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**COMPY** is a Flutter mobile app (TCC project) that connects sports practitioners in Taquara/RS, Brazil. It supports event discovery, map browsing, real-time chat, and user profiles.

- **Languages:** Dart / Flutter 3.22+ (the `package.json` and `node_modules/` at the root are Firebase CLI artifacts — not a Node project)
- **State management:** Flutter Riverpod 2.5.1
- **Routing:** GoRouter 14.2.0 (5-tab `StatefulShellRoute.indexedStack`)
- **Backend:** Firebase Auth + Firestore (`compy-tcc` project, region `southamerica-east1`)
- **Maps:** flutter_map 7.0.2 with OpenStreetMap (no API key needed)

## Commands

```bash
flutter run                   # Start the app (Android/iOS device or emulator)
flutter test                  # Run tests
flutter pub get               # Install Dart dependencies
flutterfire configure         # Regenerate lib/firebase_options.dart (required after cloning or changing Firebase project)
dart analyze                  # Run the Dart analyzer (uses analysis_options.yaml)
```

## Firebase Setup (Required Before Running)

`lib/firebase_options.dart` is gitignored and must be generated before the app will connect to Firebase:

```bash
flutterfire configure
```

Without it, `FirebaseService.ensureInitialized()` catches the error gracefully and the app falls back to in-memory mocks. The fallback is controlled by `kUseFirebaseRepos` in `lib/core/constants/app_flags.dart` — set it to `false` to force mock mode globally.

## Architecture

**Feature-First Clean Architecture.** Each feature lives under `lib/features/<feature>/` with three layers:

```
features/<name>/
  domain/       # entities, repository interfaces, use cases (pure Dart, no Flutter)
  data/         # repository implementations, remote and mock datasources
  presentation/ # pages, widgets, Riverpod providers
```

**Riverpod DI chain:** datasource provider → repository provider → use case provider → presentation provider. New features must follow this pattern.

**Mock vs. Firestore:** Every feature has both a mock datasource and a Firestore datasource. The repository implementation checks `firebaseEnabled && kUseFirebaseRepos` to decide which to use. Prefer keeping mocks in sync with Firestore schemas.

## Git Workflow

Gitflow: `main` (stable) ← `develop` ← `feature/<name>` branches. PRs target `develop`; releases merge `develop` → `main`.

Branch naming: `feature/`, `fix/`, `refactor/`, `chore/` prefixes.

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/constants/app_flags.dart` | `kUseFirebaseRepos` toggle (mock vs. Firebase) |
| `lib/core/routes/app_router.dart` | GoRouter config — all routes defined here |
| `lib/core/theme/app_colors.dart` | Color palette (WCAG AA — do not change arbitrarily) |
| `lib/core/constants/app_strings.dart` | All UI strings in PT-BR (single source of truth) |
| `firestore.rules` | Currently `allow read, write: if false` — update before deploying |

## Conventions

- All UI strings go in `app_strings.dart` (PT-BR, future i18n ready).
- New shared widgets go in `lib/shared/widgets/`.
- Models use `Equatable` for value equality (required for Riverpod provider caching).
- Page transitions are platform-aware: FadeUpwards on Android/Windows/Linux; Cupertino on iOS/macOS — do not add explicit transitions on individual routes.
- The app currently uses anonymous Firebase Auth by default; there is no login/signup UI yet.

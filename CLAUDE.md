# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**COMPY** is a Flutter mobile app (TCC project) that connects sports practitioners in Taquara/RS, Brazil. It supports event discovery, map browsing, real-time chat, and user profiles.

- **Languages:** Dart / Flutter 3.22+. The app itself has no Node dependency — the Firebase CLI used for `firebase.json`/`flutterfire configure` runs from a global `firebase-tools` install. The one exception is `tools/firestore-rules-tests/`, a small Node package that exercises `firestore.rules` against the emulator; Firestore security rules cannot be tested from Dart. It never ships with the app.
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

# Firestore security rules (needs JDK 21+ on PATH — see tools/firestore-rules-tests/README.md)
npm install --prefix tools/firestore-rules-tests   # once
npm test --prefix tools/firestore-rules-tests      # runs the rules suite against the emulator
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

Branch naming: `feature/`, `fix/`, `refactor/`, `chore/`, `style/` prefixes.

Commits and PRs never carry a `Co-Authored-By: Claude` trailer or a Claude Code signature (also enforced by `attribution` in `.claude/settings.json`).

## Caderno de campo

Every change you make to the repository gets a note in `docs/caderno_de_campo/` — without being asked, in the same commit as the change.

- One file per day, named `AnotacoesMMDDYYYY.md` (e.g. `Anotacoes09272026.md` for 27/09/2026). If today's file already exists, add a new bullet to it instead of creating another file.
- File starts with the header `Taquara, 27 de Setembro de 2026`, then one `- ` bullet per task done that day.
- Written in PT-BR, simple and direct, first person plural, like a notebook entry ("Hoje ajustamos..."): what was done and why. Length follows the task — detail it when needed, just don't turn it into a huge text. Avoid dumping file lists or code.

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/constants/app_flags.dart` | `kUseFirebaseRepos` toggle (mock vs. Firebase) |
| `lib/core/routes/app_router.dart` | GoRouter config — all routes defined here |
| `lib/core/theme/app_colors.dart` | Color palette (WCAG AA — do not change arbitrarily) |
| `lib/core/constants/app_strings.dart` | All UI strings in PT-BR (single source of truth) |
| `firestore.rules` | Per-collection rules scoped by role (profile owner, event creator, conversation member) — see the comments in the file |
| `docs/checklist-publicacao.md` | Blockers that must be handled before shipping — the app still uses the `com.example.*` template package, and changing it invalidates the Google Sign-In OAuth clients |

## Conventions

- All UI strings go in `app_strings.dart` (PT-BR, future i18n ready).
- New shared widgets go in `lib/shared/widgets/`.
- Models use `Equatable` for value equality (required for Riverpod provider caching).
- Page transitions are platform-aware: FadeUpwards on Android/Windows/Linux; Cupertino on iOS/macOS — do not add explicit transitions on individual routes.
- The app currently uses anonymous Firebase Auth by default; there is no login/signup UI yet.

## Agent skills

### Issue tracker

Issues and PRDs live as GitHub issues in `GabrielPittaBr/MVP_COMPY`, driven by the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

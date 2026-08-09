# Autenticação — COMPY

Documentação do fluxo de autenticação implementado no sprint atual.

---

## Visão Geral

O app agora exige login para entrar. A tela de entrada (`/login`) é exibida toda vez que o usuário não está autenticado. O GoRouter bloqueia o acesso às 5 abas principais e redireciona automaticamente conforme o estado do Firebase Auth.

```
App inicia
    ↓
FirebaseService.ensureInitialized()
    ↓
GoRouter.redirect() avalia authStateProvider
    ↓
Usuario não autenticado → /login
Usuario autenticado sem username → /username  (só Google: 1ª vez)
Usuario autenticado com username → /home
```

---

## Arquivos Criados / Modificados

### Novos

| Arquivo | Função |
|---|---|
| `lib/features/auth/domain/entities/auth_user.dart` | Entidade `AuthUser` (uid, email, displayName, hasUsername) |
| `lib/features/auth/domain/repositories/auth_repository.dart` | Interface do repositório |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | FirebaseAuth + GoogleSignIn + Firestore |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Implementação concreta |
| `lib/features/auth/presentation/providers/auth_providers.dart` | Providers Riverpod + AuthController |
| `lib/features/auth/presentation/widgets/auth_text_field.dart` | Campo de texto com obscureText + validator |
| `lib/features/auth/presentation/pages/login_page.dart` | Tela de login (carrossel + logo + botões) |
| `lib/features/auth/presentation/pages/signup_page.dart` | Tela de cadastro manual |
| `lib/features/auth/presentation/pages/username_page.dart` | Tela intermediária (escolha de username, pós-Google) |
| `lib/core/routes/go_router_refresh_stream.dart` | Adaptador Stream → ChangeNotifier para o router |
| `assets/images/` | Pasta para assets de imagem |

### Modificados

| Arquivo | O que mudou |
|---|---|
| `firestore.rules` | Substituído `if false` por regras baseadas em `request.auth` |
| `pubspec.yaml` | Adicionado `google_sign_in: ^6.2.1` + seção `assets:` |
| `lib/core/routes/app_router.dart` | Rotas `/login`, `/signup`, `/username`; redirect + refreshListenable |
| `lib/main.dart` | Removido sign-in anônimo automático; gate delegado ao router |
| `lib/core/constants/app_strings.dart` | Seção `// Auth` com strings PT-BR |
| `lib/core/constants/app_assets.dart` | `loginCarousel` (4 URLs) + `logoAsset` |

---

## Coleções Firestore

```
users/{uid}
  id:         String  (= uid)
  name:       String
  handle:     String  (= "@username")
  avatarUrl:  String
  email:      String
  createdAt:  Timestamp

usernames/{username_minusculo}
  uid:  String
```

- `usernames` funciona como índice de unicidade — doc id é o username em minúsculo.
- A gravação é feita via **WriteBatch atômico**: `users/{uid}` + `usernames/{username}` juntos.

---

## Fluxos de Autenticação

### A — Login com E-mail / Senha

1. Usuário informa e-mail e senha no formulário expansível da `LoginPage`.
2. `AuthController.signInWithEmail()` chama `FirebaseAuth.signInWithEmailAndPassword`.
3. `authStateProvider` (StreamProvider) emite o novo estado.
4. `GoRouter.redirect` detecta usuário autenticado com username → vai para `/home`.

### B — Cadastro Manual

1. Usuário acessa `/signup` (Link "Criar Conta" na LoginPage).
2. Preenche Nome, Username, E-mail, Senha.
3. `AuthController.signUpWithEmail()`:
   - Checa unicidade do username em `usernames/{username}`.
   - Cria conta no FirebaseAuth.
   - Grava perfil e índice no Firestore (batch atômico).
4. `authStateProvider` emite → redirect para `/home`.

### C — Login com Google (usuário existente)

1. Usuário toca "Entrar com Google".
2. `AuthController.signInWithGoogle()` abre o seletor de conta.
3. Se `users/{uid}` já existe → `hasUsername = true` → redirect `/home`.

### D — Login com Google (primeira vez)

1. Mesmo fluxo C, mas `users/{uid}` não existe → `hasUsername = false`.
2. `GoRouter.redirect` detecta `!hasUsername` → vai para `/username`.
3. Usuário escolhe username na `UsernamePage` (nome e e-mail pré-preenchidos read-only).
4. `AuthController.setUsername()` grava Firestore.
5. `authStateProvider` emite → redirect `/home`.

---

## Regras de Segurança (firestore.rules)

As regras usam a função auxiliar `signedIn()` que verifica `request.auth != null` (cobre anônimo e contas reais). Destaques:

- `users/{userId}`: leitura para qualquer autenticado; escrita só para o dono.
- `usernames/{username}`: leitura livre; criação só se `request.resource.data.uid == request.auth.uid`.
- `events`, `conversations`: escrita restrita por papel (criador do evento, membro da conversa) — ver os comentários no próprio `firestore.rules`.
- `places`: não existe. O catálogo de locais é curado e vive em código (`SportPlace.all`).

**Para publicar as regras:**

```bash
firebase deploy --only firestore:rules
```

> ⚠️ Sem o deploy as regras só existem localmente. O Firebase Console usa as regras que foram publicadas via `firebase deploy`.

---

## Passos Manuais (pré-launch)

### 1. Logo

Salve o arquivo `logo.png` (Image #2 do mockup) em:
```
assets/images/logo.png
```
O app usa `Image.asset('assets/images/logo.png')` com um fallback em código caso o arquivo não exista.

### 2. SHA-1 / SHA-256 para Google Sign-In (Android)

No Firebase Console (`compy-tcc` → Configurações do projeto → Apps Android):

```bash
# SHA-1 do keystore de debug (desenvolvimento)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Adicione o SHA-1/SHA-256 ao app Android no Console e baixe o `google-services.json` atualizado para `android/app/`.

### 3. URL Scheme no iOS (para Google Sign-In)

Em `ios/Runner/Info.plist`, adicione o `REVERSED_CLIENT_ID` que está no `GoogleService-Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.SEU_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### 4. Deploy das Security Rules

```bash
firebase deploy --only firestore:rules
```

---

## Verificação End-to-End

```
flutter pub get           ✅ (google_sign_in instalado)
dart analyze              ✅ (sem erros, apenas infos de estilo)
firebase deploy --only firestore:rules   → publicar regras
flutter run               → app abre em /login
```

Checklist manual:
- [ ] App abre direto na tela de login (não nas 5 abas)
- [ ] Cadastro manual cria conta + perfil no Firestore
- [ ] Username duplicado → mensagem de erro
- [ ] Login com e-mail/senha funciona
- [ ] Login com Google (1ª vez) → tela de username
- [ ] Login com Google (conta existente) → vai direto para /home
- [ ] Logout volta para /login
- [ ] Eventos carregam sem "permission denied"
- [ ] Criar evento funciona (participante salvo no Firestore)

---

## Próximos Passos Recomendados

- Mapear `users/{uid}` → `UserProfile` em `ProfileRepositoryImpl.getCurrentProfile()` (TODO pré-existente).
- Adicionar botão de logout na tela de Perfil.
- Índice composto para a query de chat (`members arrayContains + orderBy lastMessageAt`) — o Firestore mostra o link para criar quando rodar pela primeira vez.

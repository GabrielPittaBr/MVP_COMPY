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
Usuario não autenticado           → /login
Usuario sem username              → /username             (só Google: 1ª vez)
Usuario sem esportes escolhidos   → /onboarding/esportes  (e-mail e Google)
Cadastro completo                 → /home
```

A ordem dos degraus é o contrato, e cada um só é avaliado quando o anterior
está satisfeito. A decisão vive em `authRedirect()` — função pura, separada do
`GoRouter` justamente por ser o ponto onde um erro tranca o usuário fora ou em
loop. `test/core/routes/auth_redirect_test.dart` percorre cada estado a partir
de cada rota e prova que todo caminho estabiliza.

**Concluir o onboarding é ter passado pela tela, não ter escolhido algo.** Quem
pula grava lista vazia em `users/{uid}.favoriteSports`, e é o campo existir que
conta. Se o sinal exigisse ao menos um esporte, o "pular" viraria um loop.

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
5. Redirect para `/onboarding/esportes` — o degrau seguinte.
6. Escolha (ou "pular") gravada → redirect `/home`.

### E — Onboarding de esportes (fecha C, D e B)

1. Chega aqui quem tem username e ainda não passou pela tela.
2. `FavoriteSportsController.save()` grava `users/{uid}.favoriteSports`.
3. Depois de gravar, avisa `AuthController.markFavoriteSportsChosen()`.

O passo 3 não é enfeite: gravar no Firestore **não** dispara `userChanges()`,
então nem o stream nem o controller descobririam sozinhos que o onboarding
acabou — e o guard devolveria o usuário para a tela que ele acabou de
concluir. Como o estado do controller tem prioridade sobre o stream no guard,
é ele que faz a passagem valer na hora.

---

## O que o login com Google cria, e quando (tarefa 5)

**Conta sim, perfil não.** `signInWithCredential` cria a conta no Firebase Auth
automaticamente no primeiro login — não existe passo de "cadastro". O documento
`users/{uid}` **não** nasce ali: ele só é gravado em `setUsername()`, depois de
o usuário escolher o username. É por isso que o guard usa `hasUsername` e não a
mera existência da conta.

Esse descompasso gerava três problemas. Os três foram corrigidos:

| # | Problema | Correção |
|---|---|---|
| 1 | **Conta órfã.** Fechar o app em `/username` deixa conta no Auth sem documento em `users/`. | Aceito. No próximo login ele volta para `/username` e completa — não quebra nada, só suja a base. |
| 2 | **Falso negativo em rede ruim.** `_userHasProfile()` devolvia `false` no catch, então um usuário **já cadastrado** com internet lenta era mandado para `/username` — e ao confirmar o próprio username levava `UsernameAlreadyTakenException` no username dele mesmo, sem saída. | Duas frentes: a leitura agora estoura `ProfileLookupFailedException` em vez de mentir `false`, e a splash oferece "Tentar novamente"; e `isUsernameAvailable()` passou a aceitar o username cujo documento já aponta para o **mesmo uid**. |
| 3 | **`batch.set` sem merge no índice.** Se `usernames/{username}` já existia, a escrita virava *update* e sobrescrevia o documento inteiro. | `SetOptions(merge: true)`, casando com a regra que permite o update do dono. |

O erro de leitura tem tratamento próprio no guard: com o estado de auth em erro
e nenhum usuário utilizável em mãos, o router segura o usuário na splash. Cair
para `/login` deslogaria quem está autenticado; cair para `/username` faria
recadastrar quem já tem conta.

> **Pendente de verificação no console.** As conclusões acima vêm da leitura do
> código e da suíte de regras no emulador. Falta rodar o fluxo com uma conta
> Google nova e conferir em Authentication → Users e Firestore → `users` em que
> momento cada registro aparece, anexando a evidência aqui.

---

## Regras de Segurança (firestore.rules)

As regras usam a função auxiliar `signedIn()` que verifica `request.auth != null` (cobre anônimo e contas reais). Destaques:

- `users/{userId}`: leitura para qualquer autenticado; escrita só para o dono, com `hasOnly` limitando os campos.
- `users/{userId}/private/contact`: e-mail e demais dados de contato. Só o dono lê e escreve — o perfil é público, o contato não (RN-06).
- `usernames/{username}`: leitura livre (a checagem de disponibilidade roda **antes** do login); criação só se `request.resource.data.uid == request.auth.uid`; atualização só do documento que já pertence ao mesmo uid.
- `events`, `conversations`: escrita restrita por papel (criador do evento, membro da conversa) — ver os comentários no próprio `firestore.rules`.
- `places`: não existe. O catálogo de locais é curado e vive em código (`SportPlace.all`).

**Para publicar as regras:**

```bash
firebase deploy --only firestore:rules
```

> ⚠️ Sem o deploy as regras só existem localmente. O Firebase Console usa as regras que foram publicadas via `firebase deploy`.

---

## Passos Manuais (pré-launch)

### 1. SHA-1 / SHA-256 para Google Sign-In (Android)

No Firebase Console (`compy-tcc` → Configurações do projeto → Apps Android):

```bash
# SHA-1 do keystore de debug (desenvolvimento)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Adicione o SHA-1/SHA-256 ao app Android no Console e baixe o `google-services.json` atualizado para `android/app/`.

### 2. URL Scheme no iOS (para Google Sign-In)

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

### 3. Deploy das Security Rules

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
- [ ] Login com Google (1ª vez) → tela de username → tela de esportes
- [ ] Login com Google (conta existente) → vai direto para /home
- [ ] Cadastro por e-mail → tela de esportes antes da Home
- [ ] "Pular" na tela de esportes entra no app e não reaparece ao reabrir
- [ ] Esportes escolhidos aparecem no Perfil
- [ ] Logout volta para /login
- [ ] Eventos carregam sem "permission denied"
- [ ] Criar evento funciona (participante salvo no Firestore)

---

## Solução de problemas

Absorve o antigo `debug-auth-login.md` (incidentes de 2026-06-28 e 2026-08-09).

### Login com Google falha: `DEVELOPER_ERROR` / `ApiException: 10`

O seletor de conta abre, fecha e nada acontece. Nenhuma chamada ao Firestore chega a sair, então **não é problema de regra**.

**Causa:** a SHA-1 do keystore não está cadastrada no Firebase Console, ou foi cadastrada *depois* de gerar o `android/app/google-services.json`. Nesse caso o arquivo vem com `oauth_client: []`, e como ele é gitignored nada no repositório denuncia.

**Conserto:** cadastrar SHA-1 e SHA-256 no Console (Configurações do projeto → app Android → Impressões digitais), **depois** baixar o `google-services.json` de novo e recompilar. O provedor Google também precisa estar habilitado em Authentication → Sign-in method.

```bash
keytool -J-Duser.language=en -list -v -alias androiddebugkey   -keystore ~/.android/debug.keystore -storepass android
```

O `-J-Duser.language=en` contorna o keytool do Temurin 25, que quebra com locale pt-BR (`MissingFormatArgumentException`).

**Proteções que ficaram no código:** `test/android_google_services_test.dart` falha quando `oauth_client` está vazio, e `GoogleSignInMisconfiguredException` separa esse erro de configuração da falha transitória (antes caía no genérico "Tente novamente", que nunca resolve).

### `PERMISSION_DENIED` em qualquer operação

Quase sempre as regras locais não foram publicadas: o Console continua com as antigas. Rodar `firebase deploy --only firestore:rules` e confirmar com a suíte de `tools/firestore-rules-tests/`.

Caso específico já resolvido: a checagem de username disponível roda **antes** do login, por isso `usernames` tem leitura pública. Se essa regra voltar a exigir `signedIn()`, o cadastro por e-mail quebra no primeiro passo.

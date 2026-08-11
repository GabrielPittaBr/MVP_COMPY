# Debug — Falha no Login e Cadastro

**Data:** 2026-06-28  
**Branch:** `feature/login-e-cadastro`  
**Ambiente:** Flutter 3.44.4 · Android (SM S711B, debug)

---

## Sintoma

Nenhum dos três fluxos de autenticação funcionava:

- Login com e-mail/senha
- Cadastro manual (e-mail + username)
- Login com Google

O app abria e ficava na tela de login sem exibir nenhuma mensagem de erro visível ao usuário.

---

## Análise dos Logs (`flutter run`)

### Erro 1 — Google Sign-In: `DEVELOPER_ERROR`

```
E/GoogleApiManager: Failed to get service from broker.
E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR}
```

**Causa-raiz:** A impressão digital SHA-1 do keystore de debug nunca foi registrada no Firebase Console. Sem o SHA-1, o Google Sign-In não consegue validar que a app é legítima e retorna `DEVELOPER_ERROR`.

---

### Erro 2 — Firestore: `PERMISSION_DENIED`

```
W/Firestore: Listen for Query(target=Query(usernames/gabriel ...)) failed:
    Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
```

**Duas causas sobrepostas:**

**2a. Regras nunca foram deployadas.**  
O arquivo `firestore.rules` existia localmente, mas nunca foi publicado via `firebase deploy`. O Firebase mantinha as regras antigas (negação total), bloqueando todas as operações, mesmo de usuários autenticados.

**2b. Bug no código: `isUsernameAvailable` chamado antes da autenticação.**  
No fluxo de cadastro manual (`signUpWithEmail`), a verificação de unicidade do username é feita antes de criar a conta no Firebase Auth:

```dart
// auth_remote_datasource.dart — ordem dos passos no signup
final bool available = await isUsernameAvailable(normalizedUsername); // ← passo 1: usuário NÃO autenticado ainda
// ...
await _auth.createUserWithEmailAndPassword(...); // ← passo 2: autenticação acontece aqui
```

A regra anterior exigia `signedIn()` para ler `usernames`, o que bloqueava o passo 1 inevitavelmente.

---

## Correções

### Correção 1 — Registrar SHA-1 no Firebase Console *(ação manual)*

SHA-1 do keystore de debug (`~/.android/debug.keystore`):

```
92:33:F9:CE:B8:C1:BE:6F:F6:06:06:66:47:EE:89:19:05:3D:3B:B8
```

SHA-256 (recomendado também):

```
CF:4F:2C:CD:67:24:47:83:57:52:AB:8E:0D:A4:A1:81:E8:3C:15:E1:16:E2:AF:6D:00:F0:2A:1A:F6:67:9B:77
```

**Passos:**
1. Abrir [Firebase Console](https://console.firebase.google.com) → projeto `compy-tcc`
2. Configurações do projeto → aba **Seus apps** → app Android
3. Adicionar os dois fingerprints acima em **Impressões digitais do certificado SHA**
4. Salvar e **baixar o `google-services.json` atualizado**
5. Substituir o arquivo em `android/app/google-services.json`

---

### Correção 2 — Regra Firestore: `usernames` com leitura pública *(feita em código)*

**Arquivo:** `firestore.rules`

Antes:
```
match /usernames/{username} {
  allow read: if signedIn();
  allow create: if signedIn() && request.resource.data.uid == request.auth.uid;
}
```

Depois:
```
match /usernames/{username} {
  allow read: if true;   // ← leitura pública: checar disponibilidade não exige login
  allow create: if signedIn() && request.resource.data.uid == request.auth.uid;
}
```

**Justificativa:** Verificar se um username está disponível é uma operação pública — o código faz essa checagem antes de criar a conta, o que é o comportamento correto (evita criar uma conta e só depois descobrir que o username está ocupado). A leitura expõe apenas `{ uid }`, sem dados sensíveis.

---

### Correção 3 — Deploy das regras Firestore *(ação manual)*

Após atualizar o `google-services.json`:

```bash
firebase deploy --only firestore:rules
```

---

## O que foi resolvido automaticamente (sem ação manual)

| # | Problema | Correção |
|---|---|---|
| 1 | Regra Firestore: `usernames` bloqueava leitura sem auth | `allow read: if true` em `firestore.rules` + deploy |
| 2 | Email/Password desabilitado no Firebase Auth | Ativado via Identity Platform API |
| 3 | Regras Firestore não deployadas | `firebase deploy --only firestore:rules` executado |

---

## O que ainda precisa de ação manual (Google Sign-In)

O Google Sign-In requer ativação pelo Firebase Console porque precisa criar credenciais OAuth 2.0 automaticamente. Isso não pode ser feito via CLI sem as credenciais pré-existentes.

**Passos (1 minuto):**

1. Abrir [Firebase Console → Authentication → Sign-in method](https://console.firebase.google.com/project/compy-tcc/authentication/providers)
2. Clicar em **Google**
3. Ativar o toggle **Habilitar**
4. Colocar o e-mail de suporte: `gabrielfernandespitta@gmail.com`
5. Clicar **Salvar**
6. No terminal: `flutterfire configure` → selecionar projeto `compy-tcc` → isso regerará o `google-services.json` com os `oauth_client` corretos
7. `flutter run`

---

## Checklist de Verificação Pós-Correção

Execute na ordem:

```
[ ] 1. SHA-1 e SHA-256 adicionados no Firebase Console
[ ] 2. google-services.json substituído em android/app/
[ ] 3. firebase deploy --only firestore:rules (concluído com sucesso)
[ ] 4. flutter run
[ ] 5. Cadastro manual: criar conta nova → vai para /home ✓
[ ] 6. Username duplicado → exibe mensagem de erro ✓
[ ] 7. Login com e-mail/senha: conta existente → vai para /home ✓
[ ] 8. Login com Google (1ª vez) → vai para /username ✓
[ ] 9. Login com Google (conta existente) → vai para /home ✓
[ ] 10. Logout → volta para /login ✓
```

---

## Diagrama: Por que o login falhava

```
GOOGLE SIGN-IN
  └─ GoogleSignIn.signIn()
       └─ GoogleApiManager verifica SHA-1
            └─ SHA-1 não encontrado no Firebase
                 └─ DEVELOPER_ERROR ← bloqueio aqui

EMAIL SIGNUP
  └─ isUsernameAvailable("gabriel")
       └─ Firestore: usernames/gabriel.get()
            └─ request.auth == null (ainda não autenticado)
                 └─ PERMISSION_DENIED ← bloqueio aqui

EMAIL LOGIN
  └─ signInWithEmailAndPassword(...)
       └─ sucesso → _userHasProfile(uid)
            └─ Firestore: users/{uid}.get()
                 └─ regras nunca deployadas → PERMISSION_DENIED ← bloqueio aqui
```

---

## Reincidência — 2026-08-09

**Sintoma:** só o login com Google falhava. Seletor de conta abria, fechava, e
nada acontecia. Suspeita inicial: o `firebase deploy --only firestore:rules`
feito minutos antes.

**Não era o deploy.** O log mostrou que nenhuma chamada ao Firestore chega a
acontecer — a falha é anterior. A suíte `tools/firestore-rules-tests/` confirmou
que as regras publicadas aceitam todas as operações do fluxo (ler `users/{uid}`
inexistente, ler `usernames/{nome}` deslogado, gravar o batch de perfil).

**Causa real:** o mesmo `DEVELOPER_ERROR` da primeira vez, com uma pegada nova:

```
PlatformException(sign_in_failed,
  com.google.android.gms.common.api.ApiException: 10: , null, null)
```

`android/app/google-services.json` estava com **`oauth_client: []`**. O
`flutterfire configure` gera o arquivo sem nenhum cliente OAuth quando a SHA-1
não está cadastrada no console no momento da geração — e o arquivo é gitignored,
então nada no repositório denuncia isso.

**Conserto:** cadastrar a SHA-1 do keystore no Firebase Console (Configurações
do projeto → app Android → Adicionar impressão digital), baixar o
`google-services.json` de novo e recompilar.

```bash
keytool -J-Duser.language=en -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore -storepass android
```

**O que ficou no código para não repetir:**

- `test/android_google_services_test.dart` falha quando `oauth_client` está
  vazio, com a instrução do conserto na mensagem. Pula quando o arquivo não
  existe, já que é gitignored.
- `GoogleSignInMisconfiguredException` separa DEVELOPER_ERROR de falha
  transitória. Antes, `ApiException: 10` caía no genérico "Ocorreu um erro.
  Tente novamente." — e tentar de novo nunca resolve um erro de configuração.

**Nota:** o keytool do Temurin 25 quebra com locale pt-BR
(`MissingFormatArgumentException`); o `-J-Duser.language=en` acima contorna.

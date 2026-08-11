# Checklist de publicação

Coisas que **precisam** ser feitas antes de publicar o app, e que hoje estão
pendentes. Não é a lista completa de uma publicação na Play Store — é o que
este repositório sabe que está errado se ninguém mexer.

---

## 1. Trocar o pacote `com.example.mvp_compy`

Ainda é o nome gerado pelo template do Flutter. `com.example.*` **não é aceito
na Play Store**, e o pacote é imutável depois de publicado: escolher errado
significa perder o app e recomeçar com outro identificador.

Onde ele aparece:

| Arquivo | O quê |
|---|---|
| `android/app/build.gradle.kts:12` | `namespace` |
| `android/app/build.gradle.kts:27` | `applicationId` |
| `android/app/src/main/kotlin/com/example/mvp_compy/MainActivity.kt` | declaração `package` **e o caminho das pastas** |
| `android/app/google-services.json` | `package_name` (gerado — não editar à mão) |

O diretório `android/app/src/main/kotlin/com/example/mvp_compy/` precisa ser
renomeado junto com a declaração dentro do `MainActivity.kt`.

## 2. Fazer isso **junto** com o registro no Firebase — não em duas etapas

**Trocar o pacote invalida os clientes OAuth do Google Sign-In.** Eles são
emitidos para o par (pacote, SHA-1); mudando o pacote, o par deixa de existir e
o login com Google volta a falhar com `ApiException: 10` (DEVELOPER_ERROR) — o
mesmo erro descrito em [`debug-auth-login.md`](debug-auth-login.md), que já
derrubou este projeto duas vezes.

Ordem que evita o retrabalho:

1. Escolher o pacote definitivo e aplicá-lo nos quatro lugares acima.
2. No Firebase Console, registrar o app Android com o **pacote novo**.
3. Cadastrar as impressões digitais **antes** de gerar o `google-services.json`:
   - SHA-1 do keystore de **debug** (para continuar desenvolvendo);
   - SHA-1 do keystore de **release**;
   - se usar Play App Signing, também a SHA-1 que o **Google gera** ao assinar —
     ela aparece só depois do primeiro envio, e sem ela o login com Google
     funciona no APK local e falha para quem baixar da loja.
4. Só então baixar o `google-services.json` e colocar em `android/app/`.
5. Conferir:
   ```bash
   flutter test test/android_google_services_test.dart
   ```
   Esse teste falha quando o arquivo volta com `oauth_client` vazio, que é
   exatamente o que acontece quando a SHA-1 não estava cadastrada no passo 3.

> O `google-services.json` é gitignored. Nada no repositório denuncia que ele
> voltou quebrado — o teste acima existe só por isso.

## 3. Publicar as regras do Firestore junto

`firestore.rules` só vale em produção depois de:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Rodar a suíte antes, sempre:

```bash
npm test --prefix tools/firestore-rules-tests
```

**Agora isso bloqueia uma tela, não só a segurança.** A exclusão de conta
apaga `users/{uid}`, `users/{uid}/private/contact` e `usernames/{handle}`, e as
regras de `delete` dessas três só existem no `firestore.rules` local. Sem o
deploy acima, o botão "Excluir minha conta" falha com `PERMISSION_DENIED` no
aparelho do usuário — com o código todo certo.

---

## Pendências conhecidas que não bloqueiam a publicação

- **`users/{uid}.email` é legível por qualquer autenticado**, o que contraria a
  RN-06. A correção é mover para `users/{uid}/private/contact` — mudança de
  código, não de regra. Registrado em comentário no `firestore.rules`.
- **`_userHasProfile` engole qualquer erro de leitura** e devolve `false`. O
  guard do router então manda o usuário para `/username`, onde `setUsername`
  encontra o username dele mesmo e recusa com "já está em uso" — laço fechado a
  partir de uma falha transitória de rede.

# Checklist de publicação

Os bloqueios que este repositório conhecia foram resolvidos em 10/08/2026, na
preparação da **v0.1.0**. O documento deixa de ser lista de pendências e passa
a registrar *o que foi feito* — porque metade disso é irreversível e a outra
metade não está em lugar nenhum do código.

## Estado

| # | Item | Situação |
|---|---|---|
| 0 | Keystore de release | ✅ criado e ligado ao Gradle |
| 1 | Pacote definitivo | ✅ `br.com.compy.app` |
| 2 | `google-services.json` com OAuth | ✅ 3 `oauth_client` para o pacote novo |
| 3 | Regras e índices no Firestore | ✅ publicados e conferidos |

Verificações que sustentam a tabela: `dart analyze` sem erros, `flutter test`
169/169, `npm test --prefix tools/firestore-rules-tests` 83/83, e um
`flutter build apk --release` que sai assinado com o certificado de release
(conferido no `apksigner verify --print-certs`).

---

## 0. Assinatura de release

| | |
|---|---|
| Arquivo | `C:/Users/gabri/keystores/compy-release.jks` — **fora do repositório** |
| Formato | PKCS12, RSA 2048 |
| Alias | `compy` |
| Validade | até 26/12/2053 |
| SHA-1 | `A2:2C:C0:D8:03:1F:57:3F:BB:14:8C:9B:9B:9C:96:11:53:10:18:00` |
| SHA-256 | `67:78:4D:7A:80:0D:8B:7E:10:06:67:D8:7D:5D:9E:37:E0:A3:81:1C:75:45:3F:F2:92:F0:20:F9:50:AA:3A:0A` |

As senhas estão em `android/key.properties`, que é gitignored. O `.jks` mora
fora do repositório de propósito: assim nem um `git add -f` distraído o
publica.

> **Perder o par (`.jks` + senhas) significa não conseguir mais atualizar o app
> na loja** — só republicar com outro pacote, do zero. Faça backup dos dois
> fora desta máquina antes de qualquer outra coisa.

O `build.gradle.kts` lê o `key.properties` e **cai na chave de debug quando ele
não existe**. Isso é intencional: um clone limpo continua compilando release
para teste local. O preço é que o build não avisa quando está usando a chave
errada — daí a conferência valer o comando:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

O SHA-1 impresso tem que ser o da tabela acima.

## 1. Pacote `br.com.compy.app`

Trocado em todos os lugares, incluindo o caminho das pastas do Kotlin
(`android/app/src/main/kotlin/br/com/compy/app/`). **É imutável a partir do
primeiro envio à loja.**

O registro antigo `com.example.mvp_compy` continua existindo no projeto
`compy-tcc` e ainda aparece no `google-services.json`, que lista todos os apps
Android do projeto. Ele é inofensivo — o plugin do Google Services casa pelo
`applicationId`. Mas é por causa dele que
`test/android_google_services_test.dart` lê o `applicationId` do
`build.gradle.kts` em vez de varrer a lista: um teste que só percorresse os
clientes ficaria verde com o app apontando para o pacote errado.

## 2. App no Firebase

| | |
|---|---|
| Projeto | `compy-tcc` |
| App ID | `1:260166625635:android:d3a540c67965084979cb56` |
| SHAs cadastradas | 4 — SHA-1 e SHA-256 de **release** e de **debug** |

As SHAs entraram **antes** do download do `google-services.json`, que é a ordem
que faz o arquivo vir com `oauth_client` preenchido. Fora dessa ordem ele volta
vazio e o login com Google falha com `ApiException: 10` — ver
[`debug-auth-login.md`](debug-auth-login.md).

Tudo isso é automatizável, e foi:

```bash
firebase apps:create ANDROID "Compy" --package-name br.com.compy.app
firebase apps:android:sha:create <appId> <sha>     # uma vez por impressão
firebase apps:sdkconfig ANDROID <appId> --out android/app/google-services.json
```

O `apps:sdkconfig` **recusa sobrescrever** um arquivo existente: apague o
antigo antes.

Ao trocar de máquina de desenvolvimento, cadastre a SHA-1 do `debug.keystore`
**daquela** máquina — ela é gerada localmente e é diferente por instalação.

## 3. Regras e índices do Firestore

Publicados e conferidos. Os índices batem com `firestore.indexes.json`
(`firebase firestore:indexes`), e o deploy das regras confirmou que a versão no
ar já era a atual.

Rodar a suíte antes de todo deploy, sempre:

```bash
export JAVA_HOME="/c/Users/gabri/.jdks/temurin-25.0.3"   # o Java do PATH é 1.8
npm test --prefix tools/firestore-rules-tests
firebase deploy --only firestore:rules,firestore:indexes
```

---

## O que ainda falta para uma publicação na Play Store

Nada disto bloqueou a v0.1.0, que sai por link direto (Firebase App
Distribution). Vira bloqueio no dia em que o destino for a loja.

- **Conta de desenvolvedor** (US$ 25, uma vez) e ficha da loja: descrição,
  capturas, ícone 512×512, banner 1024×500.
- **Política de privacidade em URL pública.** O app coleta localização e dados
  de conta — a Play exige a política e o formulário de Segurança dos Dados
  declarando os dois.
- **AAB em vez de APK** (`flutter build appbundle`). A loja não aceita mais APK
  para apps novos.
- **Play App Signing.** Ao aderir, o Google reassina o app com uma chave dele.
  A SHA-1 dessa chave **só aparece depois do primeiro envio** e precisa ser
  cadastrada no Firebase igual às outras — senão o login com Google funciona no
  APK local e falha para quem baixar da loja. É a terceira vez que esta
  armadilha aparece neste documento; é a mesma sempre.

## Pendências conhecidas que não bloqueiam

- **App Check usa `playIntegrity` no release.** O `activate()` está dentro de
  um `try/catch`, então falhar não derruba o app — mas isso só vale enquanto a
  **imposição** estiver desligada no Console. Ligar a imposição sem o app
  distribuído pela Play derruba todas as leituras do Firestore de uma vez. As
  SHA-256 de release e debug já estão cadastradas, que é metade do caminho.
- **iOS continua com o pacote do template** (`com.example.mvpCompy`, em
  `lib/firebase_options.dart`). Não foi tocado porque não há build de iOS neste
  ciclo — `flutter_launcher_icons` inclusive tem `ios: false`. Refazer o mesmo
  ritual dos itens 1 e 2 quando houver.

## Pendências que já foram resolvidas

Ficam registradas porque estavam nesta lista e alguém pode procurá-las:

- ~~`users/{uid}.email` legível por qualquer autenticado~~ — resolvido em
  `428b829`: o e-mail passou a ser gravado em `users/{uid}/private/contact`,
  no mesmo batch do perfil, e a regra do bloco `private` fecha para terceiros.
- ~~`_userHasProfile` engole erro de leitura e devolve `false`~~ — a função não
  existe mais. A falha virou `ProfileLookupFailedException`, e a splash segura
  o usuário numa tela de "tentar de novo" em vez de despachá-lo para
  `/username`.
- ~~`INTERNET` só declarada no manifest de debug~~ — declarada em
  `android/app/src/main/AndroidManifest.xml`. Antes ela chegava ao release de
  carona no AAR do `google_sign_in_android`; agora não depende de terceiro.
  Conferido no APK com `aapt2 dump permissions`.

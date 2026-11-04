# Checklist de publicação

> **Auditoria de 02/11/2026:** as regras publicadas em 31/10 já aceitam `bio` e
> 16 modalidades; os 16 índices estão READY e Storage coincide com o local.
> O código integrado de amizades ainda exige publicar suas Rules e a Function
> nova. O build Android local passou, mas usa a chave de debug porque a chave
> oficial não existe nesta máquina. Não distribuir esse artefato como atualização
> da v1.0.0. Ver [evidências, comandos e validação presencial](validacao-feintec-2026.md).
>
> **03/11/2026:** as Rules com `friendships` e a Function
> `onProfileDeletedFriendships` foram publicadas — ver [amizades](amizades.md).
> A v1.0.1 saiu assinada com outra chave, que passou a ser a oficial — ver
> [item 0](#0-assinatura-de-release).

Os bloqueios que este repositório conhecia foram resolvidos em 10/08/2026, na
preparação da **v0.1.0**. O documento deixa de ser lista de pendências e passa
a registrar *o que foi feito* — porque metade disso é irreversível e a outra
metade não está em lugar nenhum do código.

## Estado

| # | Item | Situação |
|---|---|---|
| 0 | Keystore de release | ✅ `compy-release-v2.jks` desde a v1.0.1, com senha própria e backup — ver [item 0](#0-assinatura-de-release) |
| 1 | Pacote definitivo | ✅ `br.com.compy.app` |
| 2 | `google-services.json` com OAuth | ✅ `oauth_client` do pacote novo para release e para o debug de três máquinas |
| 3 | Regras e índices no Firestore | ✅ publicados e conferidos; regras republicadas em 22/10/2026 com a tarefa 14, os locais e o avatar, e em 03/11/2026 com as amizades |
| 4 | Storage: bucket, regras e CORS | 🟡 bucket ativo e regras publicadas; falta o CORS — ver [item 4](#4-storage-fotos-de-perfil) |
| 5 | Distribuição com link fixo | ✅ GitHub Releases, desde a v1.0.0 — ver [item 5](#5-distribuição-pelo-github-releases) |

Verificações que sustentam a tabela: `dart analyze` sem erros, `flutter test`
169/169, `npm test --prefix tools/firestore-rules-tests` 83/83, e um
`flutter build apk --release` que sai assinado com o certificado de release
(conferido no `apksigner verify --print-certs`).

---

## 0. Assinatura de release

Chave oficial desde a v1.0.1 (03/11/2026):

| | |
|---|---|
| Arquivo | `C:/Users/gabri/keystores/compy-release-v2.jks` — **fora do repositório** |
| Formato | PKCS12, RSA 2048 |
| Alias | `androiddebugkey` |
| Validade | até 26/05/2056 |
| SHA-1 | `92:33:F9:CE:B8:C1:BE:6F:F6:06:06:66:47:EE:89:19:05:3D:3B:B8` |
| SHA-256 | `CF:4F:2C:CD:67:24:47:83:57:52:AB:8E:0D:A4:A1:81:E8:3C:15:E1:16:E2:AF:6D:00:F0:2A:1A:F6:67:9B:77` |
| Backup | o `.jks` no Google Drive; a senha guardada em outro lugar |

A senha está em `android/key.properties`, que é gitignored. Em PKCS12 a senha
do arquivo e a da chave são uma só, então o arquivo se refaz à mão:

```properties
storeFile=C:/Users/gabri/keystores/compy-release-v2.jks
storePassword=<senha>
keyAlias=androiddebugkey
keyPassword=<a mesma senha>
```

O `.jks` mora fora do repositório de propósito: assim nem um `git add -f`
distraído o publica.

> **Perder o par (`.jks` + senha) significa não conseguir mais atualizar o app
> instalado** — cada pessoa teria que desinstalar e instalar de novo. Guarde
> os dois fora desta máquina e **separados um do outro**: o arquivo sozinho não
> assina nada, e o arquivo junto da senha assina para qualquer um.

### De onde veio esta chave

A v0.1.0 e a v1.0.0 saíram com o `compy-release.jks` original (alias `compy`,
SHA-1 `A2:2C:C0:D8:03:1F:57:3F:BB:14:8C:9B:9B:9C:96:11:53:10:18:00`). Em
03/11/2026 ele e o `key.properties` não estavam na máquina do build, e a v1.0.1
foi publicada com o que o Gradle usa no lugar deles: o
`C:/Users/gabri/.android/debug.keystore` daquela máquina. Quem tinha a v1.0.0
precisou desinstalar antes de instalar a v1.0.1.

No mesmo dia essa chave virou a oficial. Só que o `debug.keystore` usa a senha
pública `android`, e com ele qualquer pessoa que tivesse o arquivo assinaria um
APK que o celular aceita como atualização do Compy. Por isso o release usa uma
cópia com senha própria:

```bash
keytool -importkeystore -srckeystore ~/.android/debug.keystore -srcstorepass android \
  -destkeystore compy-release-v2.jks -deststoretype PKCS12 \
  -deststorepass <senha> -destkeypass <senha>
```

O `keytool -storepasswd` não serve: em PKCS12 ele troca só a senha do arquivo,
a chave continua com a antiga e o Gradle falha com `Given final block not
properly padded`.

O `debug.keystore` continua no lugar, com a senha padrão, assinando os builds
de debug. Ele não é o backup: se sumir, o Android Studio gera outro e só o
debug desta máquina muda de SHA. **Não volte para a chave antiga**, mesmo que o
`.jks` original apareça: seria outra desinstalação para todo mundo. O cadastro
dela no Firebase pode ficar, é inofensivo.

A Play Store recusa artefatos assinados com certificado de debug
(`CN=Android Debug`), e esta chave nasceu assim. No dia em que o destino for a
loja, será preciso criar uma chave de upload; com o Play App Signing, a SHA da
chave do Google também entra no Firebase (ver o fim deste documento).

### O fallback do Gradle

O `build.gradle.kts` lê o `key.properties` e **cai na chave de debug quando ele
não existe**. Isso é intencional: um clone limpo continua compilando release
para teste local. O preço é que o build não avisa quando está usando a chave
errada: em outra máquina, sem o `key.properties`, o APK sai com o debug dela e
não atualiza o app instalado. Daí a conferência valer o comando:

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
| SHAs cadastradas | 8 — SHA-1 e SHA-256 de **release** e do **debug** de três máquinas |

As SHAs entraram **antes** do download do `google-services.json`, que é a ordem
que faz o arquivo vir com `oauth_client` preenchido. Fora dessa ordem ele volta
vazio e o login com Google falha com `ApiException: 10` — ver
[`autenticacao.md`](autenticacao.md#solução-de-problemas).

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
E cadastre no app `br.com.compy.app`: em 03/11/2026 a SHA-1 de debug
`92:33:F9:CE:B8:C1:BE:6F:F6:06:06:66:47:EE:89:19:05:3D:3B:B8` estava só no app
antigo `com.example.mvp_compy`, e o login com Google falhava com
`ApiException: 10` em todo APK compilado naquela máquina (issue #33).

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

## 4. Storage (fotos de perfil)

Entrou com a foto de perfil (`feature/foto-de-perfil`, 22/10/2026). O bucket é
o `compy-tcc.firebasestorage.app`, que já aparece no `firebase_options.dart`.
As regras ficam em `storage.rules`, e a mesma suíte de
`tools/firestore-rules-tests/` cobre os dois arquivos.

> **Feito em 22/10/2026:** `firebase deploy --only storage,firestore:rules`
> publicou as duas regras juntas, o que também confirmou que o bucket está
> ativo. **Pendente:** configurar o CORS (abaixo); sem ele, o painel e o app
> no navegador não mostram as fotos.

Publicar as regras do Storage junto com as do Firestore, porque a regra de
`avatarUrl` no Firestore e a do bucket foram escritas uma para a outra:

```bash
npm test --prefix tools/firestore-rules-tests
firebase deploy --only storage,firestore:rules
```

**CORS do bucket.** O app Android não precisa, mas o Flutter Web (o painel
admin e o app rodando no Chrome) baixa a imagem por XHR e só consegue mostrar
a foto se o bucket liberar a origem. Uma vez só, com o `gcloud`:

```bash
echo '[{"origin":["*"],"method":["GET"],"maxAgeSeconds":3600}]' > cors.json
gcloud storage buckets update gs://compy-tcc.firebasestorage.app --cors-file=cors.json
```

Só `GET` fica liberado: o envio passa pelo SDK, que já é autenticado e
validado pelas regras.

## 5. Distribuição pelo GitHub Releases

O APK sai como asset de uma release no GitHub, e o QR code de download aponta
para um link que **não muda entre versões**:

```
https://github.com/GabrielPittaBr/MVP_COMPY/releases/latest/download/compy-release.apk
```

O GitHub resolve `latest` para a release mais recente que não seja rascunho
nem pré-lançamento. Até a v0.1.0 o arquivo levava a versão no nome
(`compy-v0.1.0.apk`), e cada versão nova pedia um QR code novo. A partir da
v1.0.0 o nome é sempre o mesmo, e o link continua valendo enquanto quatro
regras forem seguidas a cada versão:

1. **O asset se chama `compy-release.apk`**, sem a versão no nome.
2. **A release sai como _latest_**, sem `--prerelease` nem `--draft`.
3. **O build number sobe** (`version: X.Y.Z+N` no `pubspec.yaml`, que o Gradle
   usa como `versionCode`). O Android recusa instalar por cima um APK com
   `versionCode` menor ou igual ao instalado. A v0.1.0 foi o `+1`, a v1.0.0 o
   `+2`, a v1.0.1 o `+3` e a v1.0.2 é o `+4`.
4. **A chave é a mesma da versão anterior.** Desde a v1.0.1 é o
   `compy-release-v2.jks` do [item 0](#0-assinatura-de-release)
   (SHA-1 `92:33:…:3B:B8`); a v0.1.0 e a v1.0.0 usaram o `compy-release.jks`
   original.
   APK assinado com outra chave não atualiza o app instalado; o Android exige
   desinstalar antes, e o usuário perde a sessão.

O ritual, a partir de `main` já com o merge de `develop`:

```bash
flutter build apk --release
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk  # SHA-1 do item 0
cp build/app/outputs/flutter-apk/app-release.apk compy-release.apk
git tag -a vX.Y.Z -m "Compy vX.Y.Z" && git push origin vX.Y.Z
gh release create vX.Y.Z compy-release.apk --title "Compy vX.Y.Z" --notes-file <notas.md>
```

---

## O que ainda falta para uma publicação na Play Store

Nada disto bloqueou a v0.1.0 nem a v1.0.0, que saem por link direto (GitHub
Releases). Vira bloqueio no dia em que o destino for a loja.

- **Conta de desenvolvedor** (US$ 25, uma vez) e ficha da loja: descrição,
  capturas, ícone 512×512, banner 1024×500.
- **Política de privacidade em URL pública.** O app coleta localização, dados
  de conta e **fotos** (a foto de perfil, da galeria ou da câmera, que fica no
  Storage e é visível para os outros usuários) — a Play exige a política e o
  formulário de Segurança dos Dados declarando os três. Vale dizer na política
  que o EXIF (com a localização da foto) é removido antes do envio e que a
  exclusão da conta apaga as fotos.
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

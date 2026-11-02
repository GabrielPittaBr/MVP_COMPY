# Integração e preparação para a FEINTEC — 02/11/2026

## Git e escopo

O remoto principal é `origin` (`GabrielPittaBr/MVP_COMPY`); `fork` aponta para
`BeFinkler/MVP_COMPY`. Ambos foram consultados com fetch antes do trabalho.
A árvore estava limpa e a develop remota em `00034893`.

Integramos na ordem dos PRs #24 a #27, com merge commits e sem rebase ou squash:

- [PR #31](https://github.com/GabrielPittaBr/MVP_COMPY/pull/31): padronização dos
  detalhes, preservando `ddd4c26`. Atualizamos a branch antiga com a develop no
  merge `e03f07c`, sem conflitos. O merge em develop é
  `2c60166356a1b8514d26cde0cd25d41d69229be1`.
- [PR #32](https://github.com/GabrielPittaBr/MVP_COMPY/pull/32): amizades,
  preservando `07cc368`. O merge `0c9612c` incorpora o PR #31; o único conflito
  foi a inclusão de notas no caderno do mesmo dia, resolvido preservando ambas.
  Esta auditoria acompanha o PR antes da sua integração final.

Os diffs foram revisados por inteiro. As linhas de informações dos eventos e
os chips compactos dos cards permanecem separados; a navegação e o calendário
dos cards, a identidade reativa do Chat, os perfis públicos e as 16 modalidades
continuam no código combinado. Não há novas exigências de amizade para conversar
nem mudanças nas regras de participação, encerramento ou avaliação dos eventos.
Os preparativos de publicação `1.0.0+2` foram mantidos.

Não alteramos `main` local (`edf742f`) nem remota (`24e8e52`). Não houve deploy,
mudança de credenciais, OAuth, SHAs, pacote, assinatura ou dados de produção.

## Verificações do código combinado

| Verificação | Resultado |
|---|---|
| `dart analyze` | Código 0, sem erros ou warnings; 10 informações preexistentes |
| `flutter test --no-pub` | 509 aprovados |
| `npm test --prefix tools/firestore-rules-tests` | 219 aprovados |
| `npm test --prefix functions` | 98 aprovados |
| `npm run lint --prefix functions` | Aprovado |
| `git diff --check` | Aprovado |
| `flutter build apk --release --no-pub` | Aprovado, com ajustes locais descritos abaixo |

A correção visual isolada, já atualizada com a develop, passou em 492 testes
antes do PR #31. Os 509 são da combinação real, incluindo testes de detalhes,
evento em andamento, cards/calendário, avatares do Chat, perfis, amizades e
contrato das modalidades. Os emuladores usaram exclusivamente `demo-compy`,
com Auth, Firestore e Storage, incluindo duas contas autenticadas no fluxo de
solicitação/aceite/remoção. Nada foi criado em `compy-tcc`.

Os testes de Functions cobrem limpeza em lotes, repetição, falha parcial com
retry e perfil recriado antes do gatilho. Não comprovam a entrega real do
evento Eventarc: a execução integrada da nova Function, após exclusão pelo app
e pelo painel, permanece para homologação após publicação autorizada.

## Comparação com o Firebase publicado, somente leitura

Consultamos em **02/11/2026, 16:04 UTC** as APIs de Rules, índices, Functions,
App Check e certificados Android, usando a sessão existente do Firebase CLI.
Não consultamos documentos de usuários nem alteramos recursos remotos.

### Firestore Rules

- Release: `projects/compy-tcc/releases/cloud.firestore`.
- Ruleset ativo: `projects/compy-tcc/rulesets/f246ed84-b060-43d3-84c8-15d7273569c7`.
- Atualização: `2026-10-31T18:44:09.110842Z`.
- SHA-256 do conteúdo publicado, normalizado para LF:
  `a69a2b5959eaba1be5f047d947bc335a4fc61ff72e02192cccac4edb3e696f6d`.

**A pendência de `bio` está resolvida no ambiente publicado.** A versão atual
já aceita o campo opcional de até 160 caracteres, preserva `nameLower` e
contempla as 16 modalidades em favoritos e locais. O diagnóstico de 28/10
continua válido como registro histórico, mas não descreve o ruleset atual.

A comparação integral mostrou que o arquivo publicado coincide com
`00034893:firestore.rules`. Em relação ao código combinado, as únicas diferenças
são o bloco novo `friendships/{pairId}` e o comentário inicial sobre exclusões.
Não há outras diferenças funcionais nos blocos de perfis, dados privados,
usernames, locais, eventos, Chat, avaliações ou notificações.

O novo bloco valida o ID canônico por dois UIDs, campos, tipos e timestamps;
restringe consultas aos participantes; só permite solicitação em nome próprio
e aceite pelo destinatário; mantém a identidade imutável e limita exclusões
aos participantes. Uma leitura de par inexistente é necessária à transação,
mas fica restrita aos UIDs daquele ID. Veja o [schema e a matriz de ações](amizades.md).

### Índices, Storage e Functions

- **16 índices compostos**, todos `READY`, correspondem ao JSON local:
  nenhum ausente ou excedente. `fieldOverrides` local está vazio.
- Consultamos também `friendships.members`: o índice automático de array
  `CONTAINS` está `READY` e herda a configuração padrão. As consultas atuais
  não exigem índice composto ou configuração nova.
- Storage publicado e `storage.rules` local coincidem, normalizando CRLF/LF.
  Ruleset `a844bd8f-2a4a-468d-980a-54b9717a1d0c`, atualizado em
  `2026-10-22T21:31:08.231477Z`. Não é necessário republicar Storage.
- As **8 Functions existentes** estão `ACTIVE`, em `southamerica-east1`, com
  Node 22 e codebase `administrative`. `onProfileDeletedFriendships` ainda
  não está publicada. As oito implementações existentes não mudaram.
- A nova Function observa exclusão de `users/{uid}`, apaga somente as relações
  daquele UID em lotes de 200 e habilita retry. Não há limpeza retroativa de
  órfãos anteriores ao deploy. Durante a limpeza assíncrona, o app trata o
  perfil indisponível e permite remover a relação pela contraparte.
- App Check de Firestore e Auth continua `UNENFORCED`, segundo a API.
  Não alteramos essa configuração.

## Publicação recomendada — comandos não executados

Após autorização, partir da develop integrada, com árvore limpa e testes
aprovados. Na raiz do repositório:

```powershell
firebase deploy --project compy-tcc --only firestore:rules
firebase deploy --project compy-tcc --only functions:administrative:onProfileDeletedFriendships
```

O seletor da Function foi conferido no parser da versão instalada do Firebase
CLI: seleciona o codebase `administrative` e somente essa Function. O predeploy
configurado executa lint e build de Functions. Não usar `--only functions`
genérico nem incluir Hosting, Storage, índices ou configurações de Auth.

Recursos versionados necessários: `firestore.rules`,
`functions/src/friendships_cleanup.ts` e sua exportação em
`functions/src/index.ts`. `firebase.json` já define o codebase e o runtime.
Node 22, dependências de Functions e acesso autorizado ao projeto são necessários.
O projeto já possui gatilho Firestore de segunda geração (`onEventEnded`);
a criação do novo gatilho ainda precisa confirmar IAM/Eventarc e retry.

As Rules substituem o contrato completo de Firestore, embora a única mudança
funcional seja amizades. Sem publicá-las, as telas novas mostram erro de
permissão em vez de amizades fictícias. Sem a Function, criar e aceitar podem
funcionar, mas exclusões de contas deixam relações órfãs. Publicar ambos antes
de distribuir o aplicativo com a funcionalidade.

Depois, consultar o ruleset ativo e a Function para conferir região, documento,
estado `ACTIVE` e `RETRY_POLICY_RETRY`. Homologar exclusão com contas de teste
autorizadas pelo app e pelo painel, além do fluxo bidirecional. Esses passos
não foram executados em produção nesta auditoria.

## APK Android

Versão preservada: **1.0.0+2**; pacote `br.com.compy.app`; projeto `compy-tcc`;
App ID `1:260166625635:android:d3a540c67965084979cb56`. O arquivo local
`lib/firebase_options.dart` e `android/app/google-services.json` estão presentes
e apontam para esse app. O cliente correspondente tem OAuth Android para as
chaves cadastradas e cliente Web; o teste de configuração passou.

A API confirma **6 certificados**, SHA-1/SHA-256 de release e de duas máquinas
de debug. A chave de debug desta máquina é
`7E:9F:F0:CD:40:25:E6:CA:D7:D8:B8:66:F0:66:8C:DD:EE:7D:E8:2E`, cadastrada no
Firebase e presente no OAuth local. Isso valida a configuração, sem substituir
um login Google no aparelho.

**A assinatura oficial não está disponível nesta máquina:** não existe
`android/key.properties` nem o keystore no caminho registrado no checklist.
O Gradle existente usa a chave de debug como fallback, inclusive em release.
Não criamos nem trocamos certificados. Para atualizar a instalação oficial,
o responsável deve usar o keystore original, SHA-1
`A2:2C:C0:D8:03:1F:57:3F:BB:14:8C:9B:9B:9C:96:11:53:10:18:00`.

Compilamos o código combinado com Flutter 3.47.4 / Dart 3.13.3. O build gerou
`build/app/outputs/flutter-apk/app-release.apk` (68.440.995 bytes), não distribuído:

- `apksigner verify --print-certs`: assinatura válida, **Android Debug**.
- `aapt2 dump badging`: pacote correto, `versionName=1.0.0`, `versionCode=2`,
  minSdk 24, targetSdk 36, permissão INTERNET presente.
- SHA-256 do APK local:
  `61ee552e47a51469b32e849e5b0748bf9309dbb3f106b95a0c4732de686daf50`.

O build inicial encontrou conexão temporária do Java e hook `objective_c`
com interpretação errada do caminho com espaços. Resolveu com o mesmo SDK por
caminho curto, JDK 21 e variáveis limitadas ao processo:

```powershell
$env:JAVA_HOME = 'C:/Users/BERNAR~1/AppData/Local/CompyTooling/temurin-21-complete/jdk-21.0.12.1+1'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:/jtmp'
$env:ANDROID_HOME = 'C:/Users/BERNAR~1/AppData/Local/Android/sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
& 'C:/Users/BERNAR~1/develop/flutter/bin/flutter.bat' build apk --release --no-pub
```

Esses caminhos são desta máquina; o diretório curto temporário já existia.
O build atualiza `android/local.properties`, que é ignorado. Nenhuma configuração
versionada ou permanente foi alterada para contornar o problema. Não pulamos
validações de dependências. Os avisos de atualização futura de Gradle 8.14,
AGP 8.11.1 e Kotlin 2.2.20 não impediram a compilação.

Debug permite depuração/hot reload e usa App Check debug; release usa código
otimizado e Play Integrity. O modo de compilação não garante a chave correta:
conferir sempre o certificado. O APK local acima não atualiza a v1.0.0 oficial,
pois as assinaturas diferem. Não desinstalar a versão oficial como parte desta
auditoria. Para uma nova distribuição oficial, usar a chave original e um
`versionCode` maior que 2, conferindo antes o último número distribuído.

## Validação presencial pendente

1. Autorizar/publicar Rules e a Function, e conferir os recursos ativos.
2. Gerar o APK oficial da develop integrada com a chave original e novo número;
   conferir certificado, pacote e versão antes de instalar.
3. Em dois Androids, testar login por senha e Google, abrir os perfis por busca,
   eventos e Chat; enviar, cancelar, recusar, aceitar e desfazer amizade.
4. Conferir contagens/listas nos dois lados, reabrir o app, trocar de conta,
   nome/foto, remover foto e interromper/restabelecer conexão.
5. Conferir detalhes/andamento, cards/calendário e novas modalidades; validar
   o fluxo de exclusão de contas autorizado e a limpeza da relação.

Nenhum Android físico estava conectado. Os overflows preexistentes de
`PrimaryButton`/`EventStatusChip` no ensaio de 280 px com fonte a 150% continuam
documentados no roadmap; as novas linhas informativas passam em 280 px a 200%.
O grafo de metadados de amizades é uma consulta completa por UID; a UI limita
perfis carregados (prévia de 6 e listas de 25 por etapa), mas grande escala
exigirá paginação remota. Não declaramos homologação em produção.

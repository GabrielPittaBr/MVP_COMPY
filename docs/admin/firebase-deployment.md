# Deploy do Painel Administrativo COMPY

Este runbook cobre a configuração local e os passos manuais para Firebase App
Check, Hosting e Cloud Functions. Os comandos de deploy abaixo são operações
remotas. O estado efetivamente implantado está registrado nesta auditoria e no
ticket 18; configuração local não comprova implantação remota.

## Auditoria de produção em 2026-10-05

Blaze e billing vinculado foram confirmados pela API. O site dedicado
`compy-tcc-admin` já existe, está associado ao Web App
`1:260166625635:web:c6f717d9c7d38c4f79cb56` e está mapeado para o target
`admin` em `.firebaserc`. O painel já foi publicado em
`https://compy-tcc-admin.web.app`, release
`sites/compy-tcc-admin/releases/1791200318956000` (deploy exit code 0).
Os domínios `compy-tcc-admin.web.app` e `compy-tcc-admin.firebaseapp.com`
já estão autorizados no Firebase Authentication.

O registro App Check reCAPTCHA v3 foi concluído pelas APIs oficiais após a
criação da chave `COMPY Admin`, restrita aos dois domínios acima. O GET de
verificação confirmou `siteSecretSet: true`, TTL de 1 dia e score mínimo 0,5.
A secret de compatibilidade foi transferida diretamente da API reCAPTCHA
para a API App Check, sem ser exibida ou gravada em arquivo. A site key pública
deve continuar sendo fornecida externamente ao build. Ainda não há token debug
autorizado nem smoke test de attestation no site hospedado. Não adicione
localhost aos domínios de produção.

A conta autenticada não possui permissão para consultar os orçamentos da
conta de cobrança. O responsável confirmou que Gabriel concluiu orçamento,
limites e alertas corretamente. Nenhum orçamento ou configuração de cobrança
foi alterado pelo agente.

Os 13 índices compostos estão publicados e `READY`. Foram publicadas Rules
transitórias do snapshot `f5e5587ddf925310ea2067fbdd814eb7ecc466f2`, com deploy
exit code 0, para expand–contract; as Rules finais locais não foram modificadas
nem publicadas antecipadamente. O backfill `nameLower` atualizou nove perfis
e a verificação idempotente não encontrou novas alterações. O documento
`places/parque_do_trabalhador` ainda não existe. Antes
da migração, obtenha a URL HTTPS de uma imagem real aprovada do Parque;
a imagem Unsplash do seed não comprova esse dado. As evidências e pendências
completas estão no ticket 18.

As três Callables estão `ACTIVE`, gen2, em `southamerica-east1`, com
`enforceAppCheck: true`. Uma correção nas opções de `onCall` fixa a região
explicitamente, evitando a ordem de inicialização dos reexports ESM; o teste
de regressão verifica o metadata de deploy. Instâncias criadas por engano
nesta execução em `us-central1` foram removidas. Typecheck/lint exit code 0;
20 testes aprovados. Todas rejeitam chamadas sem credenciais (HTTP 401).
Isso não substitui smoke tests com Auth, custom claim e App Check válidos.

O deploy das Functions terminou com exit code 1 **somente após** a criação,
por falta de política de limpeza de imagens de build. Nenhuma política foi
aplicada: retenção de um dia foi recusada pela revisão automática por risco
de exclusão irreversível sem prazo autorizado. Defina explicitamente uma
retenção adequada ao rollback ou decida manter os artefatos, considerando
custo de armazenamento. Não escolher prazo financeiro/destrutivo silenciosamente.

Node 20 é o runtime atual; sua desativação está prevista para 2026-10-30 na
[tabela oficial de runtimes](https://docs.cloud.google.com/run/docs/runtimes/function-runtimes).
Planejar migração validada para runtime suportado antes de concluir o gate.

O login hospedado renderiza e o guard redireciona `/dashboard` sem sessão para
`/login`. Não há administrador com claim registrado na consulta atual; antes
do bootstrap, o responsável deve escolher uma conta existente qualificada.
O gate permanece bloqueado pela imagem do Parque, bootstrap, debug local,
attestation e smoke tests reais, validação do mobile, contract final e observação.

## Reauditoria remota em 2026-10-07

- Billing API confirmou Blaze e conta vinculada. O responsável confirmou que
  orçamento, limites e alertas foram concluídos; a conta CLI não tem acesso à
  listagem de budgets.
- Os 13 índices do Firestore estão `READY`. A release ativa das Rules é o
  conjunto transitório `71deeb21-acce-4a9f-ab0b-2df6189d640a`; Rules finais
  locais aguardam validação dos escritores de produção antes do contract.
- App Check mantém reCAPTCHA v3 configurado (`siteSecretSet: true`, TTL 1 dia,
  score mínimo 0,5), mas não há tokens de debug registrados. Enforcement
  global Firestore permanece `UNENFORCED`.
- O Web App está associado ao site Admin. Auth confirmou e-mail/senha e os dois
  domínios do Hosting autorizados. Os GETs das cinco rotas SPA e dos dois
  principais arquivos JavaScript retornaram HTTP 200.
- As três Functions gen2 estão ativas em `southamerica-east1`; chamada sem
  autenticação retornou 401 em cada endpoint. O CLI reportou exit code 1 após
  criar as funções pela ausência de política de limpeza de artefatos. Nenhuma
  política foi configurada; o prazo de retenção ainda requer decisão.
- Auth contém 16 contas, nenhuma com claim admin e nenhuma elegível hoje ao
  bootstrap (provedor password, e-mail verificado, conta habilitada). Escolha
  ou prepare uma conta apropriada antes de atribuir a claim.
- O documento `places/parque_do_trabalhador` não existe; aguarda-se a imagem
  HTTPS real aprovada. Não rode a migração com a imagem genérica do seed.
- A automação visual do navegador não conseguiu identificar a URL da janela e
  foi interrompida. Assim, os GETs não são evidência de Firebase inicializado,
  token App Check válido ou fluxo autenticado. Esses testes continuam pendentes.

## Reauditoria e retomada em 2026-10-08

Este registro substitui apenas os estados divergentes acima; não altera a
sequência expand–contract nem os critérios do ticket 18.

- Billing API confirmou Blaze (`billingEnabled: true`) e conta vinculada. O
  responsável confirmou que orçamento, limites e alertas estão configurados.
  A conta Firebase CLI não tem permissão para consultar budgets; nenhuma
  configuração financeira foi alterada.
- A configuração App Check reCAPTCHA v3 do Web App Admin permanece ativa
  (`siteSecretSet: true`, TTL 86400s, score mínimo 0.5). Os domínios padrão do
  Hosting Admin estão autorizados. Um token debug de localhost foi registrado
  pela API oficial e usado somente em memória/processo para desenvolvimento;
  seu valor não foi exibido nem salvo no repositório. Enforcement global de
  Firestore continua `UNENFORCED`.
- O arquivo real fornecido pelo responsável foi copiado para
  `admin/web/places/parque_do_trabalhador.jpg` (SHA-256 idêntico ao original,
  47.854 bytes). O asset está publicado em
  `https://compy-tcc-admin.web.app/places/parque_do_trabalhador.jpg` (HTTP 200).
  O seed do tooling Admin SDK usa essa URL HTTPS.
- A migração de `places/parque_do_trabalhador` foi executada com precondição
  `exists:false` via Firestore REST oficial autenticada pelo Firebase CLI,
  pois o ambiente não tinha Application Default Credentials para o script
  Admin SDK. Transformações de timestamp do servidor foram usadas. A leitura
  subsequente confirmou ID legado, status `active`, campos aprovados, imagem,
  GeoPoint, sete modalidades e timestamps. O script/Admin SDK foi validado
  separadamente; nenhum segredo foi criado ou salvo.
- Admin Web revalidado: analyze exit code 0; 50 testes exit code 0; build web
  release com site key pública exit code 0. Deploy seletivo do target `admin`
  exit code 0, release `1791474942013000`, versão `d425f97f183bf0e9`. Rotas
  `/`, `/login` e `/dashboard` respondem HTTP 200; sem sessão, o guard leva à
  tela de login. A imagem responde HTTP 200. Isso não equivale a login admin
  nem a um smoke test autenticado.
- Tooling Admin SDK: typecheck/lint exit code 0, 35/35 testes exit code 0.
  A política do Artifact Registry agora está configurada e confirmada como
  `firebase-functions-cleanup`, ação `DELETE`, somente artefatos com idade
  superior a `2592000s` (30 dias).
- As três Functions permanecem ativas em gen2, `southamerica-east1`, runtime
  `nodejs20`; não houve alteração de código nem redeploy nesta retomada.
  Chamadas sem Auth haviam retornado 401/`UNAUTHENTICATED`. Planejar atualização
  do runtime antes de 2026-10-30.
- Os 13 índices seguem `READY`. As Rules remotas permanecem no ruleset
  transitório `71deeb21-acce-4a9f-ab0b-2df6189d640a`; as Rules finais locais
  continuam validadas por 132/132 testes, exit code 0, mas não foram
  publicadas porque o writer mobile novo ainda não foi validado contra
  produção. Essa ordem evita bloquear clientes antigos.
- Auth: auditoria agregada encontrou 16 contas, nenhuma claim admin e nenhuma
  conta elegível ao bootstrap (habilitada, e-mail verificado e provider
  `password`). A conta indicada anteriormente está verificada, mas só tem
  provider `google.com`; o bootstrap seguro recusou promovê-la. Nenhuma senha,
  provider, e-mail ou claim foi alterado. Não escolher outra conta sem
  indicação explícita.
- O servidor local de desenvolvimento foi iniciado em
  `http://127.0.0.1:53421`; a tela `/login` carregou e o SDK emitiu o sinal de
  debug token. O processo fica sujeito à sessão atual do computador. O canal
  Flutter WebSocket de depuração apresentou erro na automação; não há evidência
  de chamada autenticada bem-sucedida ao Firestore ou às Callables.
- Próximos gates antes de Rules finais e PR/merge: preparar conta admin
  elegível e concluir bootstrap confiável; publicar/validar o app mobile novo
  em produção; fazer login real e smoke tests autorizados (Dashboard, Places,
  Users, Callables e suspensão/reativação); observar App Check/Functions. Não
  houve publicação no repositório oficial, PR ou merge.

## Bootstrap da conta Admin em 2026-10-09

- Com ADC configurado, o Admin SDK localizou a conta dedicada indicada pelo
  responsável. Ela estava habilitada e usava `password`, mas ainda não tinha
  `emailVerified` nem a claim `admin`.
- Por autorização explícita do responsável nesta sessão, o Admin SDK alterou
  somente `emailVerified` para `true`; a senha e o provider foram preservados.
  O bootstrap oficial do pacote `tools/firebase-admin` então concedeu
  `admin: true`, preservando claims existentes. Verificação final confirmou
  conta habilitada, e-mail verificado, provider `password` e claim `admin`.
  Nenhuma credencial ou identificador da conta foi persistido.
- Esta é uma exceção operacional única. Não altera a spec nem o comportamento
  do script: bootstraps futuros continuam a exigir e-mail já verificado e não
  marcam esse campo automaticamente. A pessoa deve autenticar novamente ou
  renovar o ID token para receber a claim. Refresh tokens não foram revogados,
  pois não havia necessidade demonstrada de invalidar sessões.
- Login real e smoke tests autenticados permanecem pendentes; não solicitar ou
  registrar a senha no chat. O restante do gate depende também da validação do
  novo writer mobile antes da publicação das Rules finais.

## Estado e limites

- O projeto é `compy-tcc`; o Hosting usa um target dedicado `admin` e publica
  `admin/build/web`.
- O painel usa rotas por path, sem `#`, e o Hosting reescreve rotas para
  `index.html`.
- As três Callable Functions administrativas usam `enforceAppCheck: true`.
  App Check complementa Auth, custom claim e Firestore Rules.
- Não habilite enforcement global do Firestore nem replay protection beta como
  parte deste MVP.
- Service accounts, chave secreta reCAPTCHA, token App Check de debug e arquivos
  `.env` com segredos nunca entram no Git.

## Pré-requisitos manuais

1. No Firebase Console, confirme que `compy-tcc` está no plano Blaze. Cloud
   Functions gen2 exige Blaze.
2. No Google Cloud Console, crie um orçamento e alertas de custo antes dos
   deploys. Escolha valores compatíveis com o orçamento do projeto; este
   runbook não define valores financeiros.
3. Instale/atualize o Firebase CLI por fonte oficial e autentique a conta com
   acesso ao projeto:

   ```powershell
   firebase login
   firebase projects:list
   firebase use compy-tcc
   ```

4. Crie um site de Hosting com um ID disponível escolhido no Console/CLI. O ID
   precisa ser único no Firebase; não presuma que um nome está livre:

   ```powershell
   firebase hosting:sites:create <SITE_ID> --project compy-tcc
   firebase target:apply hosting admin <SITE_ID> --project compy-tcc
   ```

   O segundo comando grava o mapeamento real do target `admin` em
   `.firebaserc`. Revise e versione essa alteração após confirmar que o site
   pertence ao projeto `compy-tcc`.

5. No Firebase Console, em **App Check → Apps**, registre/configure o app Web
   COMPY Admin para reCAPTCHA v3. No Console do reCAPTCHA, permita o domínio
   real atribuído ao Hosting (por exemplo, `<SITE_ID>.web.app` e
   `<SITE_ID>.firebaseapp.com`, conforme os domínios efetivamente exibidos).
   Guarde a site key pública para a configuração de build; mantenha a secret
   key somente no Console. Nunca adicione `localhost` à lista de domínios
   reCAPTCHA de produção.

6. Depois de iniciar o painel local pela primeira vez, registre o token de
   debug em **App Check → Apps → COMPY Admin → Manage debug tokens**. O token
   autoriza chamadas de um dispositivo sem attestation e deve permanecer fora
   do Git e de builds de produção.

## Desenvolvimento local com App Check

O app ativa o mecanismo oficial de debug do Firebase Web somente em modo debug
e em `localhost`, `127.0.0.1` ou `::1`. O token e a site key são configurações
externas ao repositório. A ausência de qualquer uma ou uma origem não local
interrompe a inicialização com uma mensagem explícita.

Na primeira execução, solicite que o SDK gere um token. Abra o DevTools do
navegador, copie o token emitido no console e registre-o no Firebase Console:

```powershell
$env:COMPY_APPCHECK_DEBUG_TOKEN = 'generate'
$env:COMPY_RECAPTCHA_V3_SITE_KEY = Read-Host 'Site key pública reCAPTCHA v3'
.\admin\tool\run_local_web.ps1
```

Nas execuções seguintes, leia o token sem gravá-lo em comandos versionados e
execute o mesmo script:

```powershell
$env:COMPY_APPCHECK_DEBUG_TOKEN = Read-Host 'Token App Check de debug registrado'
$env:COMPY_RECAPTCHA_V3_SITE_KEY = Read-Host 'Site key pública reCAPTCHA v3'
.\admin\tool\run_local_web.ps1
Remove-Item Env:COMPY_APPCHECK_DEBUG_TOKEN
Remove-Item Env:COMPY_RECAPTCHA_V3_SITE_KEY
```

Nunca use o script de debug para gerar artefato de produção ou fazer deploy.

## Build e deploy manual

Antes do build de release, carregue a site key pública no ambiente e garanta
que `COMPY_APPCHECK_DEBUG_TOKEN` não esteja definido:

```powershell
$env:COMPY_RECAPTCHA_V3_SITE_KEY = Read-Host 'Site key pública reCAPTCHA v3'
.\admin\tool\build_web.ps1
Remove-Item Env:COMPY_RECAPTCHA_V3_SITE_KEY
```

O script falha se a site key estiver ausente ou se houver token de debug no
ambiente. O build fica em `admin/build/web`. Antes de publicar, confirme que o
site ID de Hosting associado ao target `admin` e o domínio autorizado no App
Check são os valores reais do projeto.

Deploy seletivo, manual e com a conta Firebase autenticada:

```powershell
firebase deploy --only hosting:admin --project compy-tcc
firebase deploy --only functions:administrative --project compy-tcc
```

As Functions devem ser publicadas somente depois que o painel hospedado obtiver
tokens App Check válidos. Acompanhe as métricas de App Check antes de exigir
proteção em qualquer serviço. Não publique Rules finais enquanto clientes
legados ainda precisarem gravar o contrato anterior; siga a sequência
expand–contract da spec.

## Rollback

- **Hosting:** use a ação de rollback da release anterior na página Hosting do
  Firebase Console. Valide login, autorização e chamadas antes de manter o
  rollback.
- **Functions:** publique novamente a versão conhecida como válida da codebase
  `administrative`; mantenha registros `pending`, `succeeded` e `failed`.
- **Rules e contrato:** antes de retornar a um writer mobile antigo, publique
  primeiro as Rules transitórias compatíveis. Nunca reverta o cliente antes
  das Rules que ele precisa.
- **App Check:** se houver falha operacional, ajuste temporariamente o
  enforcement da Callable afetada no Console e registre a decisão. Não remova
  Firebase Auth, custom claims ou validações das Rules como contingência.
- Não apague `places/parque_do_trabalhador`, operações administrativas ou
  índices durante rollback.

## Revalidação do App Check e smoke público em 2026-10-09

- Após o responsável registrar o token de debug, a API oficial de App Check
  confirmou dois tokens associados ao Web App e a troca do token recém-registrado
  retornou HTTP 200 com um token App Check válido. Os valores secretos foram
  mantidos fora da saída, dos arquivos e do Git.
- O responsável relatou login local bem-sucedido antes do registro do token; a
  troca HTTP 200 valida o token registrado, mas não substitui a validação de uma
  chamada autenticada do painel.
- Auditoria remota confirmou billing habilitado/conta vinculada, provider
  reCAPTCHA v3 configurado (`siteSecretSet: true`, TTL `86400s`, score `0.5`),
  13/13 índices correspondentes ao arquivo local em `READY`, e as três
  Functions gen2 ativas em `southamerica-east1` com runtime `nodejs20`.
- As três Functions rejeitaram POST sem autenticação com HTTP 401. O Admin
  hospedado respondeu HTTP 200 nas rotas SPA testadas e no asset do Parque; o
  deep link `/dashboard` sem sessão redirecionou para `/login`.
- A conta dedicada consultada está habilitada, verificada, com provider
  `password` e claim `admin: true`. O local legado existe como `active`, com os
  campos aprovados e imagem HTTPS. As consultas foram somente leitura.
- As Rules remotas continuam no ruleset transitório. Não publique as Rules
  finais até confirmar o rollout/validação do writer mobile novo conforme
  expand–contract. O smoke autenticado hospedado e o período inicial de
  observação de erros, custos, App Check e Functions também continuam pendentes;
  veja o estado e as evidências atuais no ticket 18.

## Rules finais e validação de produção em 2026-10-09

- O responsável confirmou os fluxos de produção do mobile novo: Parque do
  Trabalhador apareceu na descoberta/mapa, a criação de Evento Esportivo com
  esse local funcionou e o compartilhamento no chat funcionou.
- Após essa confirmação, foi publicado somente `firestore.rules` com
  `firebase deploy --only firestore:rules --project compy-tcc --non-interactive`
  (exit code 0). Não houve redeploy de Hosting ou Functions nem alteração de
  índices.
- A release ativa verificada pela API oficial é
  `projects/compy-tcc/rulesets/24feca45-54d7-4abc-82c2-982247968be2`, atualizada
  em `2026-10-09T13:42:05.607306Z`. SHA-256 remoto e local:
  `e2b0a3c2aa15abaaea0ef9a376bc4e5a7b1f49c8a59d2924c83537943d9ea147`. A suíte
  completa validada manualmente para essas Rules: 132/132, exit code 0.
- Auditoria posterior somente leitura: 13/13 índices `READY`; as três
  Callables `ACTIVE`, gen2, `southamerica-east1`, runtime `nodejs20`. Sem Auth,
  as três continuaram protegidas (HTTP 401). As rotas hospedadas `/login`,
  `/dashboard`, `/places`, `/users` e a imagem do Parque retornaram HTTP 200.
  O responsável confirmou ainda login hospedado e chegada ao Dashboard.
- Consulta agregada somente leitura ao Cloud Logging em `2026-10-09T13:45:16Z`
  encontrou zero entradas `ERROR` de `cloud_run_revision` nas 24 horas
  anteriores. Como a consulta ocorreu poucos minutos após o deploy das Rules,
  é apenas uma fotografia inicial e não satisfaz a observação sustentada nem
  comprova métricas de App Check ou custos.
- Cloud Monitoring consultado às `2026-10-09T13:47:53Z` mostrou 19 verificações
  App Check `ALLOW` do Web App Admin na janela de 24 horas, sem resultado
  diferente de `ALLOW`; o contador agregado de veredictos de serviços do
  projeto reportou 85 `ALLOW`. A janela iniciada no horário da publicação das
  Rules ainda não tinha verificações. É necessário confirmar tráfego autenticado
  após o contract final e observar os resultados; isso não comprova custos.
- Ainda falta evidência autenticada de navegação Places/lista e detalhe,
  pesquisa e casos de perfil/conta ausentes, chamadas protegidas com Auth +
  claim + App Check, e o fluxo de suspensão/reativação usando uma conta de teste
  não administrativa designada. Não suspender uma conta real escolhida
  arbitrariamente. Também falta documentar a observação inicial de erros,
  custos, App Check e Functions; ticket 18 continua `blocked` até fechar esses
  itens.
- O responsável confirmou que as telas Places e Users estão funcionando e
  compartilhou uma captura de um perfil `@usuario12`. Consulta Admin SDK
  somente leitura pelo handle localizou exatamente um perfil e uma conta Auth
  correspondente, habilitada e sem claim administrativa. A captura não contém
  e-mail; UID e outros identificadores foram omitidos. A conta foi indicada
  como descartável, mas ainda não sofreu mutação. A sessão administrativa não
  está disponível à automação e o teste de suspensão/reativação continua
  pendente de confirmação explícita no momento da ação.

## Retomada autenticada e correção das Callables em 2026-10-09

- Na sessão hospedada autenticada, Dashboard, lista de usuários, busca por
  prefixo de `handle` e detalhe do perfil funcionaram. Inicialmente, o estado
  Auth aparecia indisponível. Cloud Logging confirmou App Check e Auth válidos,
  seguidos por HTTP 500 nas duas Callables de leitura.
- A causa foi a ausência de `initializeApp()` no entrypoint das Functions; a
  reprodução local retornou `app/no-app`. O entrypoint agora inicializa o Admin
  SDK e um teste de configuração protege essa inicialização. Typecheck, lint e
  testes: exit code 0; 21/21 testes.
- O codebase `administrative` foi implantado seletivamente em
  `compy-tcc` (Firebase CLI exit code 0). As três Callables existentes foram
  atualizadas em gen2, região `southamerica-east1`, runtime `nodejs20`; nenhum
  Hosting, Rules ou índice foi alterado nesse deploy.
- Após reload, o painel exibiu estados Auth ativos e os detalhes mínimos da
  conta descartável `@usuario12` (habilitada, provider `password`, e-mail não
  verificado). UID e e-mail foram omitidos. A conta permanece ativa; a
  suspensão/reativação continua pendente de confirmação no momento de cada
  mutação e deve ser executada pelo fluxo do próprio painel.

## Smoke tests autenticados adicionais em 2026-10-09

- Na sessão hospedada autenticada, o Dashboard carregou suas contagens; a busca
  por prefixo de handle retornou `@usuario12`, e o detalhe exibiu o perfil e o
  estado administrativo Auth. Após recarregar a rota do detalhe, o painel
  retornou à tela de login sem renderizar conteúdo protegido. Esse resultado
  confirma o guard seguro sem sessão, mas não comprova restauração da sessão nem
  deep link autenticado após refresh.
- Com autorização expressa do responsável e confirmação imediatamente antes
  de cada mudança, o painel suspendeu e depois reativou a conta descartável
  `@usuario12`. Ambas as operações foram confirmadas pela interface; o estado
  final observado foi `Ativa`. A senha e o perfil não foram alterados.
- Consulta somente leitura via Admin SDK confirmou que a conta Admin designada
  é elegível e não possui documento público `users/{uid}`. Nenhum identificador
  foi exibido ou registrado. O caso ainda precisa ser confirmado na UI pela
  busca exata após novo login manual.
- Cloud Logging, após a atualização das Functions em `14:09:13Z`–`14:09:16Z`,
  reportou zero entradas `ERROR` de Cloud Run desde `14:09:17Z` até o momento
  da consulta. Os 11 registros de verificação de Callable no
  intervalo reportaram `auth: VALID` e `app: VALID` para as três Functions.
  Esta janela é uma observação curta, não substitui observação sustentada de
  custos. O responsável confirmou que orçamento e alertas permanecem
  configurados; a conta CLI não possui permissão para listar budgets.
- O responsável confirmou previamente Places/Users e os fluxos do mobile novo
  em produção (mapa, criação de evento e compartilhamento no chat). Rules
  finais: validação manual real 132/132, exit code 0. Não houve novo deploy de
  Rules, Hosting ou índices nesta retomada.
- Ticket 18 continua bloqueado até completar, com sessão autenticada, a busca
  exata e o detalhe Auth sem perfil, validar um perfil existente sem conta Auth
  sem criar dados reais, validar deep link protegido com sessão ativa e observar
  erros/custos/App Check/Functions por período inicial suficiente. Não
  automatizar nem solicitar a senha da conta Admin.

## CRUD hospedado e observação inicial adicional em 2026-10-09

- Na sessão hospedada autenticada, Dashboard, Places e Users abriram. Busca por prefixo de nome/handle e consultas exatas por UID/e-mail retornaram resultados; a conta Admin sem perfil exibiu `Perfil não encontrado`. Busca por UID inexistente exibiu estado vazio. Uma falha transitória do Dashboard foi resolvida por `Tentar novamente`, com 9 perfis, 1 local ativo e 0 inativos.
- CRUD de Local Esportivo foi exercitado em produção com registro descartável: criação inativa, edição, ativação e desativação. O alvo ficou inativo, foi conferido sem referência em Eventos ou Mensagens de Local (4 conversas consultadas) e removido pelo Admin SDK confiável; a leitura posterior confirmou ausência. O documento do Parque permaneceu intacto. Não se alterou nenhuma conta nesta retomada; suspensão/reativação de `@usuario12` já havia sido validada e o estado final conhecido é ativo.
- Auditoria Admin SDK encontrou 9 perfis Firestore e nenhum sem Conta Auth. Não foi criado perfil sintético em produção. O comportamento UI para Perfil existente sem Conta ainda carece de fixture real segura. Comportamento de ID token já emitido não foi testado com token de usuário; seguem válidos os testes automatizados da Function e a limitação documentada de validade até a expiração.
- Deep link protegido sem sessão voltou para `/login`. Após navegação autenticada pela UI, uma carga direta de rota também exibiu login; voltar pelo histórico restaurou Dashboard autenticado. Como a automação pode iniciar uma navegação completa em outro contexto, não se conclui que haja bug, mas deep link autenticado após refresh permanece sem evidência suficiente e requer revalidação.
- Rules remotas correspondem ao arquivo local ativo (ruleset `24feca45-54d7-4abc-82c2-982247968be2`, SHA-256 `e2b0a3c2aa15abaaea0ef9a376bc4e5a7b1f49c8a59d2924c83537943d9ea147`); a suíte real final segue 132/132. API confirmou 13/13 índices `READY` (7 places, 5 events, 1 conversations). Não houve deploy nesta etapa.
- Metadados remotos confirmam três Functions `ACTIVE`, gen2, `southamerica-east1`, Node 20. As três rejeitaram Callable anônimo corretamente com HTTP 401 `UNAUTHENTICATED`; chamadas autenticadas recentes passaram por Auth e App Check. Em 60 minutos de Cloud Logging (`14:09:17Z`–`15:09:36Z`), houve 25 verificações `VALID/VALID`, três `MISSING/MISSING` das sondagens anônimas e três logs stderr `ERROR` alinhados às primeiras sondagens malformadas de teste (HTTP 400). Não houve outro erro Cloud Run nessa janela; uma consulta adicional até `15:12:24Z` encontrou 0 erros. O período é observação inicial; custo efetivo não foi acessível à identidade atual. Orçamento e alertas permanecem confirmados pelo responsável.
- Typecheck/lint/test Functions: exit code 0, 21/21. Admin SDK tooling: typecheck/lint/test exit code 0, 35/35. Mobile 200/200 e Rules 132/132 foram reutilizados de validação real anterior, sem alterações nessas áreas. A nova validação Flutter Admin ficou pendente: outro processo `flutter run` usava o SDK; `flutter analyze` ficou sem saída por mais de 20 minutos e foi interrompido, então testes e build não iniciaram. O processo preexistente não foi encerrado.
- Sem novas Rules, índices, Hosting, Functions ou mudanças Firebase críticas; sem deploy. O ticket 18 permanece bloqueado até revalidar deep link autenticado, encontrar uma forma segura de testar Perfil sem Conta Auth e token já emitido, obter observabilidade autorizada de custos/período mais longo e concluir analyze/test/build do Admin.

## Deep links, validação local e observabilidade — 2026-10-09

- Nenhum processo Flutter/Dart concorrente estava ativo. Na sessão Admin autenticada, Dashboard resistiu a refresh; as rotas de lista Users e Places funcionaram pela navegação interna e pelo histórico. Abertura direta/refresh em `/users` e `/places` no Hosting então ativo perdeu a rota e foi para `/dashboard`.
- O guard local agora mantém o destino protegido validado enquanto restaura a sessão e volta à rota original sem aceitar URLs externas. Foram executados: `flutter analyze --no-pub` (0), teste focado do app (10/10), suíte Admin (52/52) e `flutter build web --no-pub` (todos exit code 0). A build não foi release: não havia `COMPY_RECAPTCHA_V3_SITE_KEY` no ambiente, exigida pelo script de release. A correção ainda não está no Hosting; deep links de lista após refresh continuam falhando em produção até release e revalidação.
- A suíte de Users cobre por mocks Auth sem Perfil, Perfil sem Auth, estados Auth `notFound`/`unavailable`, consulta exata vazia e ausência de ações quando não há conta Auth. Nenhuma conta ou Perfil sintético foi criado em produção.
- Cloud Monitoring (7 dias, `2026-10-02T16:38:08Z`–`2026-10-09T16:38:08Z`): 91 requests nas três Functions Admin; 62 2xx, 17 4xx e 12 5xx. Os 12 5xx ocorreram nas duas Callables de leitura com sessão Chrome e verificações adjacentes `auth=VALID`/`app=VALID`; a origem da falha não aparece nos logs disponíveis. O Error Reporting API estava desabilitado e não foi habilitado. No recorte dos 30 minutos seguintes, quatro chamadas de status Auth foram bem-sucedidas (2 POST 200 + 2 OPTIONS 204), sem 5xx — amostra curta que não apaga o sinal semanal. Maior P95 horário observado das respostas 200: 1,68 s (detalhes Auth), 0,78 s (status Auth) e 2,49 s (suspensão), com poucas chamadas e sem interpretação como SLO.
- App Check do recurso Web Admin registrou 248 verificações `ALLOW/VALID` na semana. O agregado de serviços do projeto também teve 66 `ALLOW/INVALID`; é um agregado de múltiplos clientes/serviços, não uma contagem comprovada de bloqueios do painel. Firestore registrou 257 leituras e 26 escritas no projeto inteiro; são métricas, não valor faturado nem uso isolado do Admin.
- Billing API confirma Blaze e conta vinculada. Budget API retorna 403 para a identidade atual; o responsável confirma orçamento/alertas. Não há custo monetário efetivo disponível por esta identidade e nenhuma configuração de billing foi alterada.
- Três avisos `UNAVAILABLE` de agregação Firestore apareceram durante reloads rápidos do Dashboard em teste; depois os indicadores e as listas Users/Places carregaram pela navegação normal. A origem transitória ainda não foi provada. Não houve deploy, mudança de Rules, Functions, índices, contas ou dados na retomada. Ver ticket 18 para a lista de bloqueios vigentes.

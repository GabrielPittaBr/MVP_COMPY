# Painel Administrativo do COMPY

O painel é um app **Flutter Web separado do app mobile**. Pessoas com papel de
Administrador o usam para cuidar dos **Locais Esportivos** (que aparecem no mapa
e na criação de eventos) e consultar ou suspender **Contas de Usuário**. Fica
hospedado em <https://compy-tcc-admin.web.app>, no mesmo projeto Firebase do
app (`compy-tcc`, região `southamerica-east1`).

Este documento resume como o painel funciona. O passo a passo de Console,
build, deploy e rollback está no runbook
[`firebase-deployment.md`](firebase-deployment.md). Os termos seguem o
glossário em [`CONTEXT.md`](../../CONTEXT.md).

## Onde fica cada parte

| Caminho | O que é |
|---|---|
| `admin/` | O painel (Flutter Web, Riverpod, GoRouter, Material 3). Tem `pubspec` próprio e não importa código do app mobile. |
| `functions/` | Três Cloud Functions *callable* (TypeScript, 2ª geração, Node 22) para as operações de conta. |
| `tools/firebase-admin/` | Scripts locais com Admin SDK: bootstrap do primeiro Administrador, migração do Parque do Trabalhador e backfill de `nameLower`. Não vão para produção. |
| `firestore.rules`, `firestore.indexes.json` | Regras e índices compartilhados com o app mobile. |
| `tools/firestore-rules-tests/` | Testes das regras no emulador (inclui `places.test.js`). |

## Quem acessa

- **Administrador** é uma conta do Firebase Auth que tem a claim `admin: true`,
  login por senha e e-mail verificado. Falta qualquer um dos três: o painel faz
  logout e mostra "não autorizado".
- O login é só e-mail e senha: não há cadastro nem Google no painel.
- A sessão é `SESSION`: fechar o navegador exige entrar de novo.
- Todas as rotas (`/dashboard`, `/places`, `/places/new`, `/places/:id`,
  `/users`, `/users/:uid`) passam pelo mesmo guard. Sem sessão, vão para
  `/login?from=<rota>`, e depois do login voltam ao destino.
- O primeiro Administrador é criado pelo script de bootstrap
  (`npm run bootstrap-admin --prefix tools/firebase-admin -- --uid <UID>`).
  Ele só aceita uma conta habilitada, com senha e e-mail verificado. Não existe
  gestão de administradores no painel.

## Como as escritas funcionam ([ADR-0001](../adr/0001-separar-operacoes-de-locais-e-contas.md))

- **Locais Esportivos:** o painel lê e escreve direto no Firestore
  (`places/{placeId}`). As Rules só deixam o Administrador criar ou editar, e
  ninguém exclui.
- **Contas de Usuário:** dados do Auth (e-mail, providers, último login,
  `disabled`) e a suspensão passam **só** pelas Callables, que rodam com Admin
  SDK. O painel não escreve em `users/`, `usernames/` nem no Auth.
- **App Check (reCAPTCHA v3):** é exigido nas Callables. No Firestore continua
  sem imposição global por enquanto, uma decisão do MVP. Auth, claim e Rules
  continuam sendo a proteção principal.

## Funcionalidades

**Dashboard.** Três contagens: perfis no Firestore ("Usuários cadastrados"),
locais ativos e locais inativos. Atalhos para novo local, locais inativos e
busca de usuário.

**Locais Esportivos.**
- **Lista:** 20 por página, com busca por nome (prefixo) e filtros combináveis
  por status, modalidade e cidade.
- **Cadastro:** o local nasce **inativo**, com todos os campos obrigatórios.
- **Edição, ativação e desativação:** usam transação online que confere o
  `updatedAt`. Se outra pessoa salvou antes, o formulário mantém o que foi
  digitado e oferece recarregar.
- Desativar tira o local do mapa e da criação de eventos, mas eventos e
  mensagens antigas continuam mostrando o local.
- Não há exclusão.

**Usuários.**
- **Busca:** o tipo é escolhido explicitamente. Nome e handle buscam por
  prefixo, em páginas de 20; UID e e-mail buscam o valor exato.
- **Estado de cada conta:** cada página consulta todas as contas numa única
  chamada. Se essa chamada falhar, a página mostra "Estado indisponível", e
  não "ativa".
- **Casos especiais:** conta sem perfil mostra "Perfil não encontrado" e ainda
  pode ser suspensa. Perfil sem conta mostra "Conta não encontrada", sem ações.
- **Suspender** desabilita a conta e revoga as sessões; **reativar** volta a
  permitir login. As duas ações exigem motivo (10–500 caracteres) e
  confirmação, e não valem para o próprio Administrador nem para outro
  Administrador.
- **Limite:** um token de login já emitido continua válido até expirar (cerca
  de 1 hora). Por isso o painel não promete bloqueio instantâneo.

## Contratos de dados

**`places/{placeId}`.** Nenhum campo fora desta lista é aceito:

- **Nome e descrição:** `name` (3–120), `nameLower` (normalizado, sem
  acentos) e `description` (20–1.500).
- **`address`:** `street`, `city`, `cityLower` e `state` (UF) são obrigatórios;
  `number`, `complement`, `neighborhood` e `postalCode` (8 dígitos) são
  opcionais. Um campo opcional vazio é omitido.
- **Modalidades:** `sports` tem de 1 a 8 entre `futebol`, `basquete`, `volei`,
  `tenisDeMesa`, `futsal`, `corrida`, `ciclismo` e `caminhada`, e
  `primarySport` precisa estar em `sports`.
- **Resto:** `coordinates` (GeoPoint), `imageUrl` (HTTPS), `status`
  (`active`/`inactive`), e `createdAt`/`updatedAt` com hora do servidor.

**Eventos e Mensagens de Local.**
- Novos eventos guardam `placeId` e `placeSnapshot` (nome, endereço e
  coordenadas do local no momento da criação).
- Novas Mensagens de Local guardam `placeId` e `placeSnapshot` (nome, imagem e
  modalidade principal).
- Os dois são criados numa transação online, que falha sem internet: nada fica
  na fila. As Rules conferem que o local existe, está ativo e que o snapshot
  bate com ele.
- Depois de criados, `sport`, `placeId` e `placeSnapshot` não mudam.
  Documentos antigos, sem esses campos, continuam legíveis.

**Perfis (`users/{uid}`).** `nameLower` (nome normalizado para a busca) é
gravado junto com `name`. `handle` e `createdAt` não mudam depois de criados.

**Callables:**

| Function | Entrada | Saída |
|---|---|---|
| `getAdminUserAuthDetails` | `{uid}` ou `{email}` (exato) | uid, e-mail, e-mail verificado, providers, criação, último login, `disabled` |
| `getAdminUsersAuthStatus` | `{uids}` (1–20) | `{items: [{uid, disabled}]}`, omitindo contas inexistentes |
| `setUserSuspension` | `{uid, action, reason, operationId}` | uid, `disabled` final, ação, `completedAt` |

O `setUserSuspension` é idempotente pelo `operationId` (UUID gerado pelo
painel). Cada operação vira um registro em `adminOperations/{operationId}`
(`pending` → `succeeded`/`failed`), que nenhum cliente lê ou escreve:

- repetir uma operação concluída devolve o mesmo resultado;
- repetir uma operação que falhou devolve a mesma falha;
- repetir uma operação ainda `pending` termina o que faltou;
- o mesmo `operationId` com parâmetros diferentes é recusado.

## Comandos

O painel exige **Flutter com Dart ≥ 3.13.3** (`admin/pubspec.yaml`). Com um
Flutter mais antigo, `flutter pub get` em `admin/` falha.

```powershell
# Painel (dentro de admin/)
flutter pub get
flutter analyze
flutter test
.\tool\run_local_web.ps1   # dev no Chrome; precisa de COMPY_APPCHECK_DEBUG_TOKEN e COMPY_RECAPTCHA_V3_SITE_KEY
.\tool\build_web.ps1       # build de release; precisa de COMPY_RECAPTCHA_V3_SITE_KEY

# Functions
npm install --prefix functions
npm run typecheck --prefix functions
npm run lint --prefix functions
npm test --prefix functions

# Tooling Admin SDK (credenciais sempre fora do repositório; ver tools/firebase-admin/README.md)
npm test --prefix tools/firebase-admin

# Deploy seletivo (detalhes e ordem no runbook)
firebase deploy --only hosting:admin
firebase deploy --only functions:administrative
```

## Estado em 14/10/2026

A spec original tinha 45 critérios de aceite, e os conferimos um a um contra o
código.

- **Em código e com teste:** 41 já estavam prontos. Nesta revisão corrigimos
  outros dois:
  - **Offline sem cache** (mapa do app e lista de locais do painel): agora
    mostra erro com "Tentar novamente".
  - **Contraste WCAG AA** do tema do painel.
- **Correção pronta, mas fora do ar:** o retorno à rota depois de um refresh
  logado (deep link) está no código e testado, mas ainda não foi publicado no
  Hosting.
- **Operacional:** o gate de produção (ticket 18) segue `blocked`.

**Pendências:**

- [ ] **Deploy das Functions com Node 22 antes de 30/10/2026**, quando o Google
  desliga o Node 20.
- [ ] Novo build de release do painel e deploy do Hosting. Isso publica a
  correção de deep link, os ícones novos e o contraste.
- [ ] Ticket 18:
  - testar em produção o limite do token já emitido;
  - testar o caso de perfil sem conta Auth, sem criar dado artificial;
  - observar custos por mais tempo do que uma hora.
- [ ] Investigar os 12 HTTP 500 das Functions de leitura registrados no
  ticket 18. A causa provável é a janela anterior à correção do
  `initializeApp()` (09/10, 14:09 UTC), mas isso não foi confirmado.
- [ ] **Lacunas de teste:**
  - a carga de estados Auth do repositório real (`_loadAuthStatuses`);
  - um teste de emulador do registro de suspensão;
  - `setUserSuspension` chamado sem a claim;
  - um `pending` de reativação com a conta já habilitada;
  - a escrita real de Mensagem de Local em Dart (hoje só há teste de Rules);
  - nas Rules de `places`: ativação de um local pelo Administrador e
    recusa de update por um usuário comum;
  - o teste de foco por Tab, que não confere onde o foco foi parar.
- [ ] **Pequenas divergências da spec:**
  - `providerIds` não é filtrado para "os relevantes";
  - os tamanhos mínimos de nome e descrição são checados só no formulário, não
    nas Rules;
  - o Dashboard mostra 0 quando a contagem vem nula;
  - uma falha ao ler o perfil derruba a busca por UID inteira.

## Histórico

O painel nasceu de uma spec longa, decomposta em 18 tickets. Os tickets e o
registro detalhado de cada etapa continuam em `.scratch/admin-panel/issues/`.
A spec foi removida do repositório depois desta verificação; para consultá-la:

```bash
git show dee38d9:.scratch/admin-panel/spec.md
```

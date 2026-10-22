# Tarefa 14: ciclo de vida do evento (durante, pós e avaliação) + central de notificações

> **Documento de execução.** Foi escrito em 21/10/2026, numa sessão de planejamento que não alterou nenhum código.
> Uma sessão nova do Claude Code deve conseguir executar a tarefa inteira usando só este arquivo e o repositório.
> Ele substitui a exploração do código. Os caminhos e nomes foram conferidos em 21/10/2026, na `develop` em `39bc256`.

---

## 0. Como usar este documento (leia primeiro, Claude)

1. Leia o `AGENTS.md`, que traz as regras do repo (Gitflow, commits em PT-BR, caderno de campo e arquitetura), e depois este documento inteiro. O `docs/roadmap.md` §14 é o pedido original, e este documento **atualiza** esse pedido.
2. Execute na ordem: **Fase 0 → Fase 1 (design, com parada para o usuário) → Fase 2 (tickets) → Fase 3 (E2E no Chrome) → Fase 4 (merge e deploy)**. A Fase 0 foi feita em 21/10/2026. As outras fases viraram os 15 tickets de `.scratch/ciclo-vida-evento/issues/`: o design é o 01, a Fase 2 vai do 02 ao 13, o E2E é o 14 e o merge com o deploy é o 15. Siga a fronteira: o primeiro ticket aberto com todos os bloqueadores `resolved`.
3. **Autorizações dadas pelo usuário em 21/10/2026:**
   - Commitar, com um commit por ticket, na branch `feature/ciclo-vida-evento`, **sem** trailer `Co-Authored-By` e sem assinatura de agente.
   - **Publicar no fim** regras, índices e Functions no projeto `compy-tcc`, depois que tudo estiver verde.
   - **Push não foi autorizado.** O push fica com o usuário.
4. Antes de codar cada ticket, confira as **hipóteses marcadas na seção 13**. Uma revisão crítica do desenho foi interrompida para poupar créditos, então valide no código e nos testes antes de assumir.
5. A seção 9 inclui uma parada para o usuário aprovar o design. Não pule essa parada, porque o usuário pediu explicitamente para usar o **Claude Design** para pensar o visual.
6. Sempre leia o arquivo antes de editar. Use `git add` arquivo por arquivo, nunca `git add -A`/`.`; veja a seção 12.

---

## 1. Objetivo e escopo

Hoje um evento só tem o "antes". Esta tarefa entrega:

- **Durante:**
  - selo "Acontecendo agora";
  - card do evento ao vivo no topo da aba Eventos, só para participantes;
  - tela do evento em andamento, com participantes, dados do evento e atalho de chat;
  - botão **"Encerrar evento"**, só para o criador.
- **Depois:**
  - **encerramento automático** 1h depois do fim previsto;
  - **aviso único ao criador** quando o encerramento foi automático;
  - **fluxo de avaliação**: participantes (opcional), evento e local (obrigatórios);
  - **médias reais** no perfil e no local.
- **Novo, pedido em 21/10:** uma **central de notificações in-app**, com sino ao lado da engrenagem na Home. É por ela que o participante chega à avaliação depois que o evento termina.

**Fora do escopo:**
- Push com FCM, que fica no backlog D do roadmap.
- Outros tipos de notificação, como "alguém entrou no seu evento" ou "nova mensagem". O modelo fica pronto para eles, mas eles não são implementados agora.
- Chat em grupo do evento.
- Cancelar evento.
- Tela de perfil de outro usuário.

---

## 2. Decisões do usuário (21/10/2026)

| Pergunta | Resposta |
|---|---|
| Quem lembra o usuário de avaliar? | Primeiro a resposta foi "depois, numa parte só de notificações". Na pergunta seguinte, o usuário mudou: **"acho realmente bom ter a aba de notificações, talvez ao lado do ícone de configurações na tela inicial. Aborde isso no plano. Não quero mais uma aba em eventos."** A central de notificações in-app entra nesta tarefa. Push não entra. |
| Por onde o participante chega a um evento encerrado para avaliar? | **Pela central de notificações.** Não haverá seção nova ("Encerrados") na aba Eventos. |
| O criador avalia o próprio evento? | **Não.** O criador avalia **o local e os participantes**. A nota do evento vem só de quem participou. |
| Atalho de chat na tela do evento em andamento (o chat só tem conversas 1:1) | **Conversa individual.** O participante vê "Falar com o organizador", e cada pessoa da lista de participantes tem um botão de mensagem 1:1, que o criador também pode usar. |
| Commits e deploy | **"Commito e publico no fim"**: um commit por ticket, e no fim o deploy de regras, índices e Functions no `compy-tcc`. |
| Plano do Firebase | O `compy-tcc` está no **Blaze**, então Cloud Functions estão disponíveis. Isso responde a pergunta 2 do roadmap ("regra ou Function?"). |

Estas decisões viram **D14 a D17** no roadmap (ticket 15):
- **D14**: o criador não avalia o próprio evento.
- **D15**: a avaliação começa pela central de notificações in-app, sem seção nova na aba Eventos.
- **D16**: o atalho de chat do evento ao vivo é conversa 1:1.
- **D17**: eventos encerrados somem das listas (as três seções, a Home e a busca).

As decisões D5, D6, D7, D12 e D13 do roadmap continuam valendo.

---

## 3. Decisões técnicas

| Ponto | Decisão | Por quê |
|---|---|---|
| Encerramento automático | **Cloud Function agendada** `autoEndOverdueEvents` (a cada 10 min) | Evita a exceção delicada na regra de `events` (o antigo `TODO(tarefa 14)`). O status é derivado no cliente, então o atraso de até 10 min da Function não aparece na tela. |
| Status | Derivado no cliente: `endedAt` preenchido → **encerrado**; `dateTime ≤ agora < endsAt + 1h` → **acontecendo**; `agora ≥ endsAt + 1h` → **encerrado** mesmo antes da Function gravar; senão → **agendado** | Segue o roadmap. A tolerância de 1h é a constante `kEventEndTolerance`, espelhada na Function e nas regras. |
| Gravar avaliação | **Callable** `submitEventRatings`: valida tudo no servidor e grava avaliações, agregados, `ratedBy` e notificação numa **transação** | As regras não fazem laço (não dá para validar N participantes) e têm limite de 20 `get()` por lote, sem garantia de cache. A callable grava de forma atômica, não permite avaliação duplicada e deixa `ratings` 100% fechada ao cliente (D13). |
| App Check na callable nova | `enforceAppCheck: false` | O Firestore está sem imposição por decisão do MVP (`docs/admin/firebase-deployment.md`). A web não ativa App Check, e o build debug do Android usa token de debug que precisaria de registro: com imposição, o teste no Chrome e o debug quebrariam. As callables do admin continuam com `enforceAppCheck: true`. |
| Onde ficam as médias | Coleção nova **`ratingSummaries/{targetType}_{targetId}`**, com escrita só pelo Admin SDK | `places` tem contrato estrito de 11 campos: `SportPlace.tryFromFirestore` devolve `null` com qualquer campo extra, `validPlace()` usa `hasOnly` e o admin tem testes contra campos de nota. `users` usa `validProfile()` com `hasOnly`, e um campo extra quebraria a edição do próprio perfil. Com a coleção separada, nenhum contrato existente muda. |
| Aviso de encerramento automático (D5) | **Sai o campo `creatorNotifiedOfAutoEnd`** da modelagem do roadmap. O aviso é a **notificação** do criador: o diálogo único aparece na primeira leitura depois que o app abre e grava `readAt`. | Um único mecanismo, com a mesma garantia de que o aviso aparece uma vez só. |
| Quem cria notificações | Gatilho **`onEventEnded`** (`onDocumentUpdated('events/{eventId}')`), na transição "sem `endedAt`" → "com `endedAt`" | Cobre o encerramento manual e o automático pelo mesmo caminho. O id determinístico `eventEnded_{eventId}` torna a criação idempotente, porque gatilhos podem ser entregues mais de uma vez. |
| Codebase das Functions | As novas entram em `functions/` (codebase `administrative`), cada uma com a **região explícita** | Renomear o codebase faria o CLI apagar e recriar as Functions do admin. Isso fica registrado na documentação. |
| Encerrados nas listas | Somem de "Todos os eventos", "Criados por mim", "Participando", da Home ("Eventos próximos") e da busca | O usuário não quer seção nova. Também resolve o problema de hoje: todas as consultas ordenam do **mais antigo** com `limit`, então eventos passados empurram os atuais para fora. |
| Entrar em evento | Liberado enquanto agendado ou acontecendo. Negado depois de encerrado, também na regra. | Impede que alguém entre depois do fim só para poder avaliar. |

**Conflito a registrar na ADR:** o ticket 17 do painel admin (`.scratch/admin-panel/issues/17-...md`) fixou "ratings só `user`/`event`, sem avaliação fictícia de Local Esportivo". Ele é reaberto porque agora a avaliação de local é **real**. O documento `places/{id}` continua com os mesmos 11 campos, e a média fica em `ratingSummaries`.

---

## 4. Estado atual do código (o que a exploração encontrou)

### 4.1 Eventos

**`Event`** fica em `lib/shared/models/event.dart`. É um model compartilhado por Home, Events e Maps, e não existe DTO.
- **Campos obrigatórios:** `id`, `title`, `sport` (`Sport`), `location`, `coordinates` (`LatLng`), `dateTime`, `skillLevel`, `totalSpots`, `remainingSpots`, `bannerUrl`, `creator` (`UserSummary`).
- **Campos opcionais:** `placeId`, `placeSnapshot` (`EventPlaceSnapshot`), `durationMinutes` (padrão 60), `description`, `participants` (`List<UserSummary>`).
- **Getters:**
  - `isFull`
  - `endsAt => dateTime + durationMinutes`
  - `participantIds`, derivado de `participants`
- **`toMap()`:**
  - grava `title`, `titleLower`, `sport`, `location`, `coordinates` (GeoPoint), `geohash`, `dateTime`, `durationMinutes`, `endsAt` (Timestamp), `skillLevel`, `totalSpots`, `remainingSpots`, `bannerUrl`, `creator` (map), `description`, `participants` (lista de maps) e `participantIds`;
  - grava `placeId` e `placeSnapshot` quando existem.
- **`fromMap()`:**
  - documento sem `dateTime` vira `DateTime.now()`;
  - documento sem `durationMinutes` deriva a duração de `endsAt`, ou cai em 60 min.
- **`copyWith`** é parcial: só aceita `id`, `location`, `coordinates`, `durationMinutes`, `remainingSpots`, `participants`, `placeId` e `placeSnapshot`.
- **`props`** lista os 16 campos do construtor.
- Não há status, `endedAt` ou qualquer enum de estado.

**`EventsRemoteDataSource`** fica em `lib/features/events/data/datasources/events_remote_datasource.dart`. Todas as consultas são `get()` com `orderBy('dateTime')` ascendente.
- **`fetchPage({startAfter, limit=10, sportName, skillLevelNames, dayStart, dayEnd})`**
  - Monta `where sport ==`, `where skillLevel whereIn` e o intervalo de dia em `dateTime`.
  - Depois aplica `orderBy('dateTime').limit()` e `startAfterDocument`.
  - **Não tem limite inferior**, então os eventos passados vêm primeiro.
- **`fetchCreatedBy(uid, {limit=50})`:** `where('creator.id', ==)` + `orderBy('dateTime')`.
- **`fetchJoinedBy(uid, {limit=50})`:** `where('participantIds', arrayContains)` + `orderBy('dateTime')`.
- **`searchByTitlePrefix`:** `orderBy('titleLower')`, com range por prefixo e `limit` de 20.
- **`searchBySports`:** `whereIn` em `sport`, com `limit` de 20.
- **`fetchById`.**
- **`join(eventId, userMap)`:** transação que valida vagas e faz `arrayUnion` em `participants` e `participantIds`, mais `remainingSpots - 1`. Não confere início nem fim.
- **`create(draft, selectedPlace)`:** transação que lê `places/{id}`, valida se o local está ativo e aceita o esporte, monta o `EventPlaceSnapshot` e faz `set`.

**`EventsRepositoryImpl(this._remote)`** fica em `lib/features/events/data/repositories/events_repository_impl.dart`.
- Em todo método, o modo mock é `!kUseFirebaseRepos || _remote == null`, e o store usado é `InMemoryEventsStore.instance`.
- `fetchCreatedBy` e `fetchJoinedBy` aplicam o filtro da folha de filtros **no cliente** (`_matching`).
- `search` junta as duas consultas, remove duplicatas e ordena por data.
- A interface e as exceções (`EventFullException`, `EventPlace*Exception`, `EventCreationOfflineException`) ficam em `lib/features/events/domain/repositories/events_repository.dart`.
- Os use cases ficam em `lib/features/events/domain/usecases/` (`create_event.dart`, `get_event_detail.dart`, `join_event.dart`) e são repasses finos.

**Providers** ficam em `lib/features/events/presentation/providers/events_providers.dart`. Nenhum deles é `autoDispose`.
- `eventsRemoteDataSourceProvider`, `eventsRepositoryProvider` e os providers dos use cases.
- `eventsFilterProvider` (`StateProvider<EventsFilter>`).
- `paginatedEventsProvider` (`AsyncNotifier` `PaginatedEventsController`, `pageSize = 10`, com `loadMore()` e `hasMore`).
- `myEventsProvider` e `joinedEventsProvider`: `FutureProvider`s que leem o uid de `currentUserSummaryProvider` e funcionam no mock.
- `eventDetailProvider` (`FutureProvider.family<Event?, String>`, leitura única).
- `invalidateEventLists(WidgetRef)`.
- A busca fica em `search_providers.dart` (`searchQueryProvider` e `searchResultsProvider`, com debounce de 500ms).

**Páginas:**
- **`events_list_page.dart`**
  - `_Sections` monta um `CustomScrollView` com `addSection(title, content)`. Seção vazia some, e a divisória só aparece da segunda seção em diante.
  - "Todos os eventos" esconde lotados no cliente, depois da paginação.
  - O pull-to-refresh chama `invalidateEventLists`, e o scroll a menos de 200px do fim chama `loadMore`.
  - **O card ao vivo entra como primeiro sliver**, antes de `addSection(AppStrings.eventsSectionMine, ...)`.
- **`event_detail_page.dart`**
  - Tem `SliverAppBar`, banner, título, linhas de esporte, data (`DateFormat('EEEE','pt_BR')` + `DurationFormat.timeRange`) e duração, "Criado por:" com `_CreatorTile` (o "+" é decorativo), descrição, `'Participantes (N)'` com `ParticipantsAvatars`, mapa estático e `PrimaryButton` "Participar"/"Evento sem vagas".
  - **Bug conhecido:** "Participar" aparece para quem já participa e para o criador.
  - Os SnackBars têm texto fixo no código.
- **`create_event_page.dart`**
  - `_minDurationMinutes = 15`, `_maxDurationMinutes = 720`.
  - O seletor de data usa `firstDate: DateTime.now()`, mas **nada impede escolher um horário anterior a agora no dia de hoje**, então dá para criar evento já ao vivo ou já encerrado.
  - O `_submit()` monta `Event(id: '', ..., participants: [criador], remainingSpots: totalSpots - 1)`.
- **`participants_avatars.dart`:** pilha de `CircleAvatar` com `CachedNetworkImageProvider(url)`. Quebra com URL vazia.

**`EventCard`** fica em `lib/shared/widgets/event_card.dart`, com `{event, actionLabel, onAction, disableWhenFull=true}`.
- Mostra o esporte, um ícone de calendário **sem data**, o título, `'${location}, ${remainingSpots} vagas restantes'`, o banner de 88×72 e um CTA pill.
- **Não existe selo nem chip de status** em lugar nenhum.

**Mock:** `InMemoryEventsStore` (`lib/features/events/data/datasources/in_memory_events_store.dart`) é um singleton com `watchAll()` (stream broadcast que ninguém usa), `snapshot`, `snapshotMatching`, `createdBy`, `joinedBy`, `getById`, `join` e `add`.
- **Bug:** `add(draft)` mantém `id: ''`, então o evento criado no mock quebra a rota de detalhe.
- As fixtures ficam em `lib/features/home/data/datasources/mock_events.dart` (`MockEvents.nearby`):
  - os 4 eventos começam 1 a 5 dias no futuro, então nenhum está ao vivo ou encerrado;
  - nenhum tem `placeId`;
  - o usuário mock é `u_joao`. Ele cria o `evt_003`, mas **não está entre os participantes**, o que quebra a invariante "criador participa".

**Home:**
- `HomeRemoteDataSource.watchEvents({limit = 50})` (`lib/features/home/data/datasources/home_remote_datasource.dart`) faz `collection('events').orderBy('dateTime').limit(50).snapshots()`. É a única consulta em tempo real de eventos.
- `HomeRepositoryImpl.watchNearbyEvents` filtra por distância (10 km) no cliente.
- O `nearbyEventsProvider` (`lib/features/home/presentation/providers/home_providers.dart`) é um StreamProvider.
- `HomePage` usa `EventCard(actionLabel: 'Participar')`, que só navega.

**Rotas** ficam em `lib/core/routes/app_router.dart`, na classe `AppRoutes`:
- Fora do shell: `/`, `/login`, `/signup`, `/username` e `/onboarding/esportes`.
- **Shell** (`StatefulShellRoute.indexedStack`):

  | Branch | Rotas |
  |---|---|
  | 0 | `/home` (filhas `maps`, `search`, `configuracoes` → `UnderConstructionPage`) |
  | 1 | `/events` (filha `:id` → `EventDetailPage`) |
  | 2 | `/create` |
  | 3 | `/chat` (filhas `nova` e `:conversationId`) |
  | 4 | `/profile` (filhas `esportes`, `insignias` e `editar`) |

- A navegação ao detalhe é `context.go('${AppRoutes.events}/${id}')`.
- O shell é desenhado por `_ScaffoldWithNavBar` (StatelessWidget) no fim do arquivo.
- `authRedirect()` é uma função pura testada em `test/core/routes/auth_redirect_test.dart`. A lista `rotasDoApp` dessa suíte **deve ganhar as rotas novas**.

**Tempo:**
- **Não existe relógio injetável.** O código chama `DateTime.now()` direto em vários pontos.
- O único padrão injetável é `DayLabel.of(date, {now})` (`lib/core/utils/day_label.dart`).
- `DurationFormat.short(min)` e `DurationFormat.timeRange(start, min)` ficam em `lib/core/utils/duration_format.dart`.

### 4.2 Regras do Firestore (`firestore.rules`, 499 linhas, `rules_version = '2'`)

- **Helpers globais:**
  - `signedIn()`
  - `isAdmin()`, que é `request.auth.token.admin == true`
  - `changed()`, que é `request.resource.data.diff(resource.data).affectedKeys()`
- **Cabeçalho:** delete é negado por padrão, com uma exceção: a exclusão de conta apaga `users/{uid}`, `users/{uid}/private/contact` e `usernames/{u}`. O cabeçalho também cita "Campos ainda não implementados (`endedAt`) estão marcados com TODO".
- **`events`** (≈ linhas 146 a 258):
  - Helpers: `isCreator()` (`resource.data.creator.id == uid`), `ownerUnchanged()`, `spotsCoherent()`, `newPlaceSnapshotMatchesCurrentPlace()` (com `get`/`exists` em `places`), `historicalEventFieldsUnchanged()` (sport, placeId e placeSnapshot imutáveis), `joinedIdsBefore()` (`get('participantIds', [])`) e `isJoin()`.
  - `isJoin()` exige que só `participants`, `participantIds` e `remainingSpots` mudem, que entre exatamente o próprio uid no fim dos dois arrays e que as vagas caiam em 1. **Não olha tempo nem fim.**
  - `create`: `creator.id == uid`, `participantIds == [uid]`, `totalSpots > 0`, vagas coerentes e snapshot do local. **Não tem `hasOnly`.**
  - `update`: `(isCreator() && ownerUnchanged() && spotsCoherent() && historicalEventFieldsUnchanged()) || isJoin()`. **O criador consegue gravar qualquer outro campo**, inclusive `endedAt`.
  - `delete`: false.
  - Antes de `isJoin` há um `TODO(tarefa 14)`, sobre a exceção para qualquer participante gravar `endedAt` depois de `endsAt + 1h`. **Esse TODO deve ser removido**, porque a Function cuida disso.
- **`ratings`** (≈ linhas 445 a 497):
  - `read: false`.
  - `create`: `fromUid == uid` + `validRating()` (chaves exatas, `targetType in ['user','event']`, `stars` inteiro de 1 a 5, `comment` com até 500 caracteres, e abaixo de 3 estrelas o comentário é obrigatório).
  - `update` e `delete`: false.
  - Tem outro `TODO(tarefa 14)` sobre `get()` de participação. **O bloco inteiro é substituído** (seção 7).
- **`users/{userId}`:**
  - `validProfile()` com `hasOnly(['id','name','nameLower','handle','avatarUrl','createdAt','favoriteSports'])`.
  - O teste `users.test.js` garante que `ratingAverage: 5` é negado.
  - A subcoleção `private/{docId}` é só do dono.
- **`places`:** `validPlace()` com os 11 campos exatos (`name`, `nameLower`, `description`, `address`, `sports`, `primarySport`, `coordinates`, `imageUrl`, `status`, `createdAt`, `updatedAt`). A escrita é só do admin; `get` é liberado a qualquer usuário logado.
- **`conversations`:** só membros, com exatamente 2 membros.
- **`adminOperations`:** tudo negado.

### 4.3 Cloud Functions (`functions/`)

- **Pacote:**
  - `package.json`: `"type": "module"`, `engines.node: "22"`, `firebase-functions ^6` (6.6.0 instalado) e `firebase-admin ^13` (13.10.0).
  - Scripts: `build` (tsc), `typecheck`, `lint` (`eslint src test`) e `test` (`npm run build && node --test lib/test/*.test.js`).
  - `tsconfig`: NodeNext, ES2022 e `outDir: lib`. O `lib/` está no gitignore.
  - ESLint: `no-explicit-any` é erro.
- **`src/index.ts`:**
  - `initializeApp()` + `setGlobalOptions({ region })`.
  - Exporta `administrativeFunctionsRegion`, `getAdminUserAuthDetails`, `getAdminUsersAuthStatus` e `setUserSuspension`.
- **`src/config.ts`:** `administrativeFunctionsRegion = 'southamerica-east1'`.
- **Padrão** (`admin_auth_read.ts` e `user_suspension.ts`):
  - interfaces de gateway (portas);
  - fábricas de handler puras, `createXHandler(gateway) => async (request) => result`, com validação estrita e `HttpsError` com mensagem em PT-BR;
  - adaptadores reais que chamam `getFirestore()`/`getAuth()` **dentro dos métodos, nunca no topo do módulo**;
  - o wiring `onCall(opts, (req) => createXHandler(...)(req))`;
  - `administrativeCallableOptions = { region, enforceAppCheck: true }`, em `admin_auth_read.ts`.
- **Lição registrada (ESM):** os re-exports rodam antes do `setGlobalOptions`. Por isso **cada função passa `region` nas próprias opções**. Um deploy antigo caiu em `us-central1` por causa disso.
- **Testes** (`functions/test/*.test.ts`):
  - `node:test` + `node:assert/strict`, só com fakes, sem emulador e sem `firebase-functions-test`. Os nomes são em PT-BR.
  - `config.test.ts` confere `callable.__endpoint.region` deep-equal `['southamerica-east1']` de cada export. **Inclua as Functions novas nele.**
  - Contagem registrada: 21 testes.
- **Não existe** nenhum `onSchedule` nem gatilho `onDocument*` ainda.
- **`firebase.json`:**
  - `functions`: `[{ source: "functions", codebase: "administrative", runtime: "nodejs22", predeploy: [lint, build] }]`.
  - emuladores: `auth` 9099, `firestore` 8080, `ui.enabled: false` e `singleProjectMode: true`. **Não há emulador de Functions.**
- **Índices** (`firestore.indexes.json`), 5 compostos em `events`:
  - `sport+dateTime`
  - `skillLevel+dateTime`
  - `sport+skillLevel+dateTime`
  - `creator.id+dateTime`
  - `participantIds CONTAINS+dateTime`
- **Deploy (runbook `docs/admin/firebase-deployment.md`):** `firebase deploy --only functions:administrative --project compy-tcc` e `firebase deploy --only firestore:rules --project compy-tcc`. O princípio é *expand–contract*: não publicar regra que quebre o app já instalado.

### 4.4 Perfil, locais e avaliações hoje

- **`RatingSummary`** fica em `lib/features/profile/domain/entities/rating_summary.dart`: `{average: double, count: int, breakdown: Map<int, double>}` (fração de 0 a 1 por estrela) e `hasRatings => count > 0`.
- **`ProfileRepositoryImpl`** (`lib/features/profile/data/repositories/profile_repository_impl.dart`) devolve `rating: const RatingSummary(average: 0, count: 0, breakdown: {})` **fixo** no caminho Firestore.
- **`MockProfile.current`** (`lib/features/profile/data/datasources/mock_profile.dart`) usa 4.8 e 12.
- **Usos de `UserProfile.rating`:**
  - `mock_profile.dart:57`
  - `profile_repository_impl.dart:36`
  - `profile_page.dart:76`
  - testes: `test/features/home/categories_provider_test.dart:24`, `test/features/profile/edit_profile_page_test.dart:88` e `test/features/profile/favorite_sports_page_test.dart:35`
- **`RatingBreakdown`** (`lib/features/profile/presentation/widgets/rating_breakdown.dart`):
  - mostra `average.toStringAsFixed(1)` com **ponto** ("4.8");
  - estrelas `Icons.star`/`star_border` na cor `AppColors.warning`;
  - `'${count} avaliações'` fixo no código, sem singular;
  - barras `LinearProgressIndicator` de 5 a 1;
  - estado vazio `_NoRatingsYet` com `AppStrings.profileNoRatings`/`profileNoRatingsHint`, em primeira pessoa.
  - O teste `test/features/profile/rating_breakdown_test.dart` fixa '4.8' e '12 avaliações'.
- **`SportPlace`** (`lib/shared/models/sport_place.dart`):
  - **não tem campos de nota**, e `hasRatings` foi removido no commit `9621af9`;
  - `tryFromFirestore` exige **exatamente** os 11 campos, `nameLower == TextNormalizer.normalize(name)`, descrição de 20 a 1500 caracteres, `imageUrl` https, `status` `active|inactive` e `createdAt`/`updatedAt` como Timestamp.
- **`PlaceDetailsSheet`** (`lib/features/maps/presentation/widgets/place_details_sheet.dart`):
  - StatelessWidget `{place, onCreateEvent, onShare}`, com `DraggableScrollableSheet`;
  - a linha de nota antiga ficava **logo abaixo de `_SportsWrap`**;
  - o `_RatingRow` antigo pode ser recuperado com `git show 9621af9^:lib/features/maps/presentation/widgets/place_details_sheet.dart`.
- **Locais:**
  - `placesRepositoryProvider` usa **sempre** o Firestore e não tem mock;
  - `placeByIdProvider` (`FutureProvider.family`) busca um local por id;
  - tudo isso fica em `lib/features/maps/presentation/providers/maps_providers.dart`.
- **Perfil de outro usuário:** não existe. Não há rota `/profile/:uid`.

### 4.5 Chat (1:1 apenas)

- `Conversation.idBetween(a, b)` ordena os dois uids e junta com `_`. **Lança `ArgumentError` se `a == b`.**
- As regras de `conversations` exigem `members.size() == 2`.
- **Abrir uma conversa:** o `openConversationProvider` fica em `lib/features/chat/presentation/providers/chat_providers.dart`. O padrão canônico está em `lib/features/chat/presentation/pages/new_conversation_page.dart` (`_open`):

  ```dart
  final me = await ref.read(currentUserSummaryProvider.future);
  final id = await ref.read(openConversationProvider).call(me: me, peer: peer);
  ref.invalidate(paginatedConversationsProvider);
  ref.invalidate(conversationProvider(id));
  if (!mounted) return;
  context.go('${AppRoutes.chat}/$id');
  ```

  O original tem trava contra reentrada e SnackBar `AppStrings.chatOpenConversationError`.
- **Avatar seguro:** `PeerAvatar({peer, radius})` (`lib/features/chat/presentation/widgets/peer_avatar.dart`) é o único widget que trata URL vazia. Com URL vazia, `CachedNetworkImageProvider('')` quebra em tempo de execução.

### 4.6 Shell, startup e utilidades

- **`main.dart`:** `initializeDateFormatting('pt_BR')`, depois `FirebaseService.instance.ensureInitialized()` e por fim `ProviderScope(CompyApp())`.
- **`lib/core/services/firebase_service.dart`:**
  - com `kUseFirebaseEmulators` ligado, chama `useAuthEmulator('localhost', 9099)` e `useFirestoreEmulator('localhost', 8080)`;
  - o App Check só é ativado fora da web (debug provider no debug, Play Integrity no release).
- **`app.dart`:** `MaterialApp.router`, sem listeners. **Nada roda "uma vez depois de abrir o app"**, e não existe `shared_preferences`.
- **`_ScaffoldWithNavBar`** é o primeiro widget montado em toda rota do shell. É o lugar natural do diálogo único: vira `ConsumerStatefulWidget`.
- **Diálogos:** não existe widget compartilhado. O padrão inline é `showDialog<bool>` com `AlertDialog`, `TextButton(Cancelar)` e `TextButton(ação destrutiva, cor AppColors.error)`, como em `lib/features/profile/presentation/pages/edit_profile_page.dart`.
- **Uid atual:**
  - `currentUserSummaryProvider` (`lib/features/profile/presentation/providers/profile_providers.dart`) funciona no mock;
  - `currentUserIdProvider` (`chat_providers.dart`) é síncrono;
  - `authStateProvider` (`lib/features/auth/presentation/providers/auth_providers.dart`).
- **Exclusão de conta:** `AuthRemoteDataSource._deleteUserDocuments(uid)` (`lib/features/auth/data/datasources/auth_remote_datasource.dart`) monta um batch que apaga `usernames/{u}` (se existir), `users/{uid}/private/contact` e `users/{uid}`.

### 4.7 Strings, tema e widgets compartilhados

- **`lib/core/constants/app_strings.dart`:**
  - uma classe `AppStrings` de `static const`, agrupada por comentários;
  - os prefixos são `common*`, `nav*`, `home*`, `search*`, `maps*`, `events*` (lista), `event*` (evento/formulário), `profile*`, `chat*`, `auth*`, `onboarding*` e `settingsTitle`;
  - string com parâmetro vira `static String x(String y) => '...';`.
  - **Toda string nova entra aqui.**
- **`lib/core/theme/app_colors.dart`** (WCAG AA; não mudar as cores existentes):

  | Grupo | Cores |
  |---|---|
  | Marca | `primary` #1F3A8A, `primaryDark` #0B2566, `secondary` #10B981 |
  | Superfícies | `background`/`surface` #FFFFFF, `surfaceMuted` #F1F1F4, `surfaceCard` #F7F7F8 |
  | Texto | `onSurface` #0A0A0A, `onSurfaceMuted` #6B7280 |
  | Linhas | `outline` #E2E2E5, `outlineSoft` #EFEFF1 |
  | Estado | `success` #10B981, `warning` #F59E0B (estrelas), `error` #DC2626 |

- **Fonte e tema:**
  - Inter via google_fonts (`app_text_styles.dart`).
  - `AppTheme.light` (Material 3): AppBar centralizada sem elevação, inputs preenchidos com raio 28, FilledButton com raio 32.
  - Os widgets usam `TextStyle` inline, com padding de página de 20px e 24px entre seções.
- **`lib/shared/widgets/`:**
  - `AppBottomNav`
  - `CustomSportMarker`
  - `EventCard`
  - `PrimaryButton({label, onPressed, icon})`
  - `SecondaryButton({label, onPressed})`
  - `RoundedTextField({hint, controller, maxLines, maxLength, ...})`
  - `SportIcon({sport, size, background})`
  - `SportSelectTile`
- **`Sport`** tem `label`, `icon`, `color`, `storageName`, `tryParse` e `parseList`. Os valores são `futebol`, `basquete`, `volei`, `tenisDeMesa`, `futsal`, `corrida`, `ciclismo` e `caminhada`.
- **`GreetingHeader`** (`lib/features/home/presentation/widgets/greeting_header.dart`):
  - Row com avatar à esquerda, `Spacer`, "COMPY", `Spacer` e `IconButton` da engrenagem;
  - recebe os callbacks `onAvatarTap` e `onSettingsTap`;
  - a `HomePage` faz `onSettingsTap: () => context.push(AppRoutes.settings)`.

### 4.8 Testes

- **Dart:**
  - `flutter_test` puro, sem mocktail ou mockito.
  - Os fakes são escritos à mão (`class _X implements Repo` com `noSuchMethod`) ou forçam o mock com `XRepositoryImpl(null)`.
  - Provider overrides em `ProviderScope`/`ProviderContainer`.
  - GoRouter inline nos testes de página.
  - O README cita 208 testes.
- **Fixtures com data fixa no passado:**
  - `test/features/events/events_repository_impl_test.dart` usa `DateTime(2026, 9, 1, 19)` nas linhas ≈174, 179 e 268. O grupo das seções escreve no store singleton, então a ordem dos testes importa.
  - `tools/firestore-rules-tests/events.test.js`, em `eventoNovo()`, usa `dateTime 2026-09-01T19:00Z` e `endsAt 20:00Z`.
  - **As duas viram datas relativas a agora**, porque com as regras e os filtros novos esses eventos contam como encerrados.
- **Regras:**
  - `tools/firestore-rules-tests/`, com `node:test` + `@firebase/rules-unit-testing` 4 + `firebase-tools` local 15.31.
  - Script: `firebase emulators:exec --only firestore --project demo-compy "node --test --test-concurrency=1"`.
  - Arquivos: `events`, `users`, `places` e `conversations`, com 132 casos.
  - Helpers em `events.test.js`: `as(uid)`, `anonimo()`, `resumo(uid)`, `eventoNovo()`, `eventoComLocal()`, `placeDocument()`, `semear(dados, id)` (via `withSecurityRulesDisabled`) e `entrar(db, uid, {remainingSpots})`.

### 4.9 Ambiente da máquina (21/10/2026)

- **Ferramentas:**
  - Flutter **3.47.7**, Dart **3.13.5**.
  - `firebase-tools` global **15.22.0**.
  - Node **24.21.0** e npm 12.2. As Functions pedem Node 22; o emulador usa o Node do host e só avisa.
- **Java:**
  - No PATH só há **Java 8 (JRE)**, que não serve.
  - JDKs utilizáveis: **`C:\Users\gabri\.jdks\temurin-25.0.3`** (atende o "21+") e `C:\Users\gabri\.jdks\openjdk-26`.
  - O wrapper `tools/scripts/run-firestore-rules-tests.ps1` procura `JAVA_HOME` ou `C:\Java\temurin-21`, que **não existe** aqui.
  - Por isso, defina `JAVA_HOME` antes de rodar. Confira se o wrapper aceita a versão 25; se não aceitar, rode o `npm test` direto com o JDK no PATH.
- **Sandbox:** já houve erro `Unable to establish loopback connection` do Java dentro do sandbox de agentes. Se acontecer, rode fora do sandbox.
- **Chrome:** a extensão **claude-in-chrome** estava conectada ("Browser 1", Windows).
- **Linha de base:** o `dart analyze` dá **0 erros e 10 avisos informativos** que já existiam (`prefer_const_*` e `withOpacity`). Código novo não acrescenta avisos.
- **Arquivos locais:** `android/app/google-services.json` e `lib/firebase_options.dart` aparecem como modificados, mas a diferença é **só fim de linha** (CRLF). **Nunca** entram em commit.

---

## 5. Modelo de dados

### 5.1 `events/{eventId}`: campos novos

Os três campos ficam **ausentes** enquanto o evento está aberto. O create do cliente **não** os envia, e a regra proíbe.

| Campo | Tipo | Quem grava | Significado |
|---|---|---|---|
| `endedAt` | Timestamp | O criador, no encerramento manual (`serverTimestamp`), ou a Function | Fim real. Ausente ou nulo = não encerrado. No automático vale `endsAt + 1h`, um valor determinístico. |
| `endedAutomatically` | bool | O criador grava `false`; a Function grava `true` | Diferencia o encerramento manual do automático. |
| `ratedBy` | array de uid | Só a callable | Quem já enviou a avaliação. A tela usa para "Avaliar"/"Você já avaliou", e a callable usa para a idempotência. Qualquer usuário logado lê, mas é só quem avaliou, não o quê. |

### 5.2 `ratings/{eventId}_{fromUid}_{targetType}_{targetId}`

`eventId`, `fromUid`, `targetType` (`user` | `event` | `place`), `targetId`, `stars` (inteiro de 1 a 5), `comment` (opcional, até 500 caracteres) e `createdAt`.
- Só a callable grava.
- **Ninguém lê pelo cliente** (D13).
- O id composto impede avaliação duplicada.

### 5.3 `ratingSummaries/{targetType}_{targetId}` (nova)

`targetType`, `targetId`, `count` (inteiro), `sum` (inteiro), `starCounts` (`{ '1': n, '2': n, '3': n, '4': n, '5': n }`) e `updatedAt`.
- O app calcula `average = sum / count` e `breakdown[i] = starCounts[i] / count`.
- Quem está logado lê. Só a callable grava, com `FieldValue.increment`.

### 5.4 `users/{uid}/notifications/{notificationId}` (nova)

Id determinístico `eventEnded_{eventId}`.

| Campo | Tipo | Observação |
|---|---|---|
| `type` | string | `'eventEnded'` (único tipo por enquanto; o modelo aceita outros no futuro) |
| `eventId`, `eventTitle`, `sport`, `creatorId` | string | Cópias do evento, para a lista não precisar ler o evento |
| `endedAutomatically` | bool | Muda o texto e dispara o diálogo do criador |
| `createdAt` | Timestamp | Ordenação da lista (desc) |
| `readAt` | Timestamp ou null | Nulo = não lida. O criador que encerrou manualmente já recebe preenchido, porque vai direto avaliar. |
| `completedAt` | Timestamp ou null | A callable preenche quando a pessoa avalia. A lista mostra "Avaliado". |

O texto **não** é gravado no documento. O app monta título e corpo a partir de `type` e dos campos, com as strings em `AppStrings`, o que deixa o texto pronto para i18n.

---

## 6. Cloud Functions (especificação)

Todas ficam em `functions/src/` e seguem o padrão handler-factory + gateway + fakes. Cada uma passa `region: administrativeFunctionsRegion` nas próprias opções. Exporte as três no `index.ts` e acrescente as regiões no `config.test.ts`.

### 6.1 `event_lifecycle.ts`: `autoEndOverdueEvents`

```ts
// Tolerância espelhada de kEventEndTolerance (Dart) e das regras.
export const eventEndToleranceMs = 60 * 60 * 1000;
export const autoEndLookbackMs = 2 * 24 * 60 * 60 * 1000;

export interface OverdueCandidate { readonly id: string; readonly endsAt: Date; readonly hasEndedAt: boolean }
export interface AutoEndGateway {
  listEndsAtBetween(fromExclusive: Date, toInclusive: Date): Promise<OverdueCandidate[]>;
  endIfStillOpen(eventId: string, endedAt: Date): Promise<boolean>; // transação
}
export function createAutoEndOverdueEventsHandler(gateway: AutoEndGateway, now: () => Date) {
  return async (): Promise<number> => {
    const cutoff = new Date(now().getTime() - eventEndToleranceMs);
    const from = new Date(cutoff.getTime() - autoEndLookbackMs);
    let ended = 0;
    for (const c of await gateway.listEndsAtBetween(from, cutoff)) {
      if (c.hasEndedAt) continue;
      if (await gateway.endIfStillOpen(c.id, new Date(c.endsAt.getTime() + eventEndToleranceMs))) ended++;
    }
    return ended;
  };
}
export const autoEndOverdueEvents = onSchedule(
  { schedule: 'every 10 minutes', region: administrativeFunctionsRegion, timeZone: 'America/Sao_Paulo' },
  async () => { await createAutoEndOverdueEventsHandler(createFirestoreAutoEndGateway(), () => new Date())(); },
);
```

- **Gateway Firestore:**
  - consulta `where('endsAt', '>', from).where('endsAt', '<=', to).orderBy('endsAt').limit(500)`;
  - `endIfStillOpen` faz `runTransaction`: relê, e se o documento existe e não tem `endedAt`, grava `update({ endedAt: Timestamp.fromDate(endedAt), endedAutomatically: true })`.
- **Por que não `where('endedAt', '==', null)`:** o campo fica **ausente** nos eventos abertos, e o Firestore não casa campo ausente com `== null`.
- **Eventos legados sem `endsAt`** não entram na consulta. Isso não faz falta, porque o app já os trata como encerrados pelo tempo.
- **Testes com fakes:**
  - só os vencidos entram;
  - quem já tem `endedAt` é ignorado;
  - o valor gravado é `endsAt + 1h`;
  - uma corrida simulada (`endIfStillOpen` devolvendo `false`) não conta;
  - a janela inclui a borda exata de `agora - 1h`.

### 6.2 `event_notifications.ts`: `onEventEnded`

- `onDocumentUpdated({ document: 'events/{eventId}', region: administrativeFunctionsRegion }, handler)`.
- **Função pura** `planEventEndedNotifications(before, after)`:
  - devolve `[]` se `before.endedAt` já existia ou se `after.endedAt` não existe;
  - senão, devolve um rascunho por uid de `after.participantIds`, ou dos ids de `participants` se o documento for legado.
- **Rascunho:** `{ type: 'eventEnded', eventId, eventTitle, sport, creatorId, endedAutomatically, createdAt: serverTimestamp, readAt: (uid == creatorId && !endedAutomatically) ? serverTimestamp : null, completedAt: null }`.
- **Gravação:** `doc.create(data)` para cada um, ignorando `ALREADY_EXISTS` (código gRPC 6). **Não** use `set`, porque a reentrega do gatilho zeraria o `readAt` de quem já leu.
- **Testes:**
  - transição sem → com `endedAt` cria N notificações;
  - updates sem transição (join, `ratedBy`) não criam nada;
  - manual: a notificação do criador vem lida;
  - automático: a do criador vem não lida;
  - o id é determinístico.

### 6.3 `event_ratings.ts`: `submitEventRatings`

- `onCall({ region: administrativeFunctionsRegion, enforceAppCheck: false }, (req) => handler(req))`. O motivo do `enforceAppCheck: false` vai num comentário no código.
- **Payload:**

  ```ts
  { eventId: string;
    event?: { stars: number; comment?: string };   // proibido para o criador; obrigatório para os demais
    place?: { stars: number; comment?: string };   // obrigatório se o evento tem placeId; proibido se não tem
    participants: Array<{ uid: string; stars: number; comment?: string }> } // opcional (pode ser [])
  ```

- **Parse estrito**, que lança `invalid-argument`:
  - objeto puro com chaves exatas;
  - `eventId` string não vazia com até 128 caracteres;
  - `stars` inteiro de 1 a 5;
  - `comment` string, aparada com `trim`, de até 500 caracteres; vazia vira "sem comentário";
  - **abaixo de 3 estrelas exige comentário não vazio**;
  - participantes sem uid repetido.
- **Validação contra o evento**, feita **dentro da transação**:

  | Situação | Erro |
  |---|---|
  | Evento não existe | `not-found` |
  | Não encerrado, isto é, sem `endedAt` e com `agora < endsAt + 1h` | `failed-precondition` |
  | Quem chama não está em `participantIds` (ou nos ids legados) | `permission-denied` |
  | Já está em `ratedBy` | `already-exists` |
  | O criador mandou `event` | `invalid-argument` |
  | Um não criador não mandou `event` | `invalid-argument` |
  | `place` não corresponde ao `placeId` do evento | `invalid-argument` |
  | Participante avaliado fora de `participantIds`, ou igual a quem chama | `invalid-argument` |

- **Transação:**
  1. Lê o evento e `users/{uid}/notifications/eventEnded_{eventId}`. Todas as leituras vêm antes das escritas.
  2. Cria `ratings/{eventId}_{uid}_{tipo}_{alvo}` para cada alvo com `tx.create`. Se a avaliação já existe, a transação falha com `already-exists`.
  3. Atualiza cada `ratingSummaries/{tipo}_{alvo}` com `tx.set(..., { targetType, targetId, count: increment(1), sum: increment(stars), starCounts: { [String(stars)]: increment(1) }, updatedAt: serverTimestamp() }, { merge: true })`.
  4. Atualiza o evento com `tx.update({ ratedBy: arrayUnion(uid) })`.
  5. Se a notificação existe, grava `tx.update({ completedAt: serverTimestamp(), readAt: <manter se já tem, senão serverTimestamp()> })`.
- **Resposta:** `{ ratedTargets: number }`.
- **Testes com fakes:** a matriz de validação inteira, mais "criador avalia local e participantes", "participante sem participantes avaliados" e "evento legado sem local".

### 6.4 Emulador de Functions

- `firebase.json` → `emulators.functions = { "port": 5001 }`.
- O emulador **não dispara `onSchedule`**. A agenda fica coberta pelos testes unitários. No E2E, o encerramento automático é simulado gravando os campos (seção 11.3), e isso dispara o gatilho de verdade.

---

## 7. Regras do Firestore (especificação, com esboço)

Atualize o cabeçalho:
- tire a frase sobre `endedAt` com TODO;
- registre que a exclusão de conta também apaga `users/{uid}/notifications`.

Siga o estilo do arquivo: comentário por bloco citando a tarefa e o porquê.

```
// events — dentro de match /events/{eventId}
function lifecycleFields() { return ['endedAt', 'endedAutomatically', 'ratedBy']; }
function isEnded() { return resource.data.get('endedAt', null) != null; }
// Documentos anteriores à tarefa 3 não têm `endsAt`; o app assume 1h.
function plannedEnd() {
  return resource.data.get('endsAt', resource.data.dateTime + duration.value(60, 'm'));
}
function withinTolerance() { return request.time < plannedEnd() + duration.value(1, 'h'); }

function isManualEnd() {
  return isCreator()
      && !isEnded()
      && changed().hasOnly(['endedAt', 'endedAutomatically'])
      && request.resource.data.endedAt == request.time
      && request.resource.data.endedAutomatically == false
      && request.time >= resource.data.dateTime
      && withinTolerance();
}
// isJoin(): acrescentar `!isEnded() && withinTolerance()` às condições atuais.

allow create: if <condições atuais>
              && !request.resource.data.keys().hasAny(lifecycleFields());
allow update: if (isCreator() && !isEnded() && ownerUnchanged() && spotsCoherent()
                  && historicalEventFieldsUnchanged()
                  && !changed().hasAny(lifecycleFields()))
              || isManualEnd()
              || isJoin();
```

```
// ratings — substituir o bloco inteiro
match /ratings/{ratingId} {
  // Tarefa 14. Só a callable submitEventRatings (Admin SDK) grava. D13: ninguém lê.
  allow read, write: if false;
}
match /ratingSummaries/{summaryId} {
  allow read: if signedIn();
  allow write: if false;
}
```

```
// dentro de match /users/{userId}
match /notifications/{notificationId} {
  allow read: if signedIn() && request.auth.uid == userId;
  allow update: if signedIn() && request.auth.uid == userId
                && resource.data.get('readAt', null) == null
                && changed().hasOnly(['readAt'])
                && request.resource.data.readAt == request.time;
  // Exclusão de conta: o dono apaga as próprias notificações.
  allow delete: if signedIn() && request.auth.uid == userId;
  allow create: if false;
}
```

**Testes de regra** (`npm test --prefix tools/firestore-rules-tests`):
- **`events.test.js`:**
  - `eventoNovo()` passa a aceitar `{ inicio, duracaoMin }`, com padrão relativo a `Date.now()` (começa daqui a 1h).
  - Casos novos:
    - criar com `endedAt`, `endedAutomatically` ou `ratedBy` → nega;
    - criador encerra evento em andamento com `serverTimestamp()` → permite;
    - visitante encerra → nega;
    - criador encerra antes do início → nega;
    - criador encerra depois de `endsAt + 1h` → nega;
    - encerrar duas vezes → nega;
    - criador muda `endedAutomatically` para `true` → nega;
    - criador mexe em `ratedBy` → nega;
    - criador edita a descrição depois de encerrado → nega;
    - join em evento encerrado (com `endedAt`) → nega;
    - join depois de `endsAt + 1h` → nega;
    - join durante o evento → permite;
    - documento legado sem `endsAt` usa `dateTime + 60min`.
- **`ratings.test.js` (novo):**
  - qualquer create, read, update ou delete em `ratings` → nega;
  - `ratingSummaries`: leitura logado → permite, deslogado → nega, escrita → nega.
- **`notifications.test.js` (novo):**
  - o dono lê → permite;
  - outro usuário lê → nega;
  - o dono marca `readAt` com `serverTimestamp()` → permite;
  - o dono mexe em outro campo → nega;
  - o dono marca de novo uma notificação já lida → nega;
  - create → nega;
  - o dono apaga → permite;
  - outro apaga → nega.
- Atualize a contagem de casos no `tools/firestore-rules-tests/README.md` e no README raiz.

---

## 8. App Flutter (especificação por área)

### 8.1 Status e relógio

- **Arquivo novo `lib/shared/models/event_status.dart`:**

  ```dart
  enum EventStatus { scheduled, happening, ended }
  const Duration kEventEndTolerance = Duration(hours: 1);
  const int kMaxEventDurationMinutes = 720; // usar também em create_event_page.dart
  extension EventLifecycle on Event {
    EventStatus statusAt(DateTime now) { /* endedAt != null → ended; now < dateTime → scheduled;
      now < endsAt + tolerância → happening; senão ended */ }
    bool isOverdueAt(DateTime now) => statusAt(now) == EventStatus.happening && !now.isBefore(endsAt);
    bool hasRated(String uid) => ratedBy.contains(uid);
  }
  ```

- **`Event` ganha:**
  - `final DateTime? endedAt;`
  - `final bool endedAutomatically;` (padrão false)
  - `final List<String> ratedBy;` (padrão const [])
  - os três entram no construtor, no `fromMap` (`(data['endedAt'] as Timestamp?)?.toDate()` e equivalentes), no `copyWith` e nos `props`;
  - **o `toMap()` não grava os três**, porque a regra de create proíbe.
- **Arquivo novo `lib/core/providers/clock_providers.dart`:**
  - `clockProvider = Provider<DateTime Function()>((_) => DateTime.now)`;
  - `nowProvider = StreamProvider<DateTime>` que emite o `clock()` atual e repete a cada 30s.
  - **Nos testes de widget, sobrescreva os dois com valor fixo**, porque um timer periódico pendente derruba o teste.
- **`create_event_page.dart`:**
  - impede início no passado (mensagem e botão bloqueado);
  - usa `kMaxEventDurationMinutes`.

### 8.2 Listas

- **`EventsRemoteDataSource.fetchPage`, `fetchCreatedBy` e `fetchJoinedBy`** ganham o parâmetro `notBefore`, que vira `where('dateTime', >= notBefore)`.
  - `notBefore = agora - (12h + 1h)`: duração máxima mais a tolerância.
  - Com filtro de dia, use `max(dayStart, notBefore)`.
  - Os índices atuais servem, porque o limite fica no mesmo campo do `orderBy`.
- **`EventsRepositoryImpl`** recebe `DateTime Function() clock` (padrão `DateTime.now`) e remove do resultado quem tem `statusAt(agora) == ended`. O mock faz o mesmo.
- **`PaginatedEventsController.loadMore`** continua buscando a próxima página enquanto a página filtrada vier vazia e houver `hasMore`, com limite de algumas voltas. Isso evita o spinner infinito quando a tela não chega a rolar.
- **"Participando":** um provider de stream **sem filtro** (`joinedActiveEventsProvider`, com `snapshots()` em `fetchJoinedBy` + `notBefore`) alimenta:
  1. o card ao vivo: `status == happening`, **independente do filtro** da aba;
  2. a seção "Participando": não encerrados, com `EventsFilter.matches` aplicado no cliente como hoje.
- **"Criados por mim"** passa a ter `notBefore` e esconde encerrados. Pode continuar sendo Future ou virar stream.
- **Home:** `watchEvents` ganha `where('dateTime', >= notBefore)` e a lista filtra encerrados no cliente, usando o clock.
- **Busca:** filtra encerrados **só no cliente**, porque a consulta por prefixo de título não aceita um segundo intervalo sem índice novo.
- **Nenhum índice composto novo é necessário.**

### 8.3 Selo e `EventCard`

- **Widget novo `lib/shared/widgets/event_status_chip.dart`:**
  - "Acontecendo agora": ponto verde `secondary` mais texto **escuro** (`onSurface`) em fundo `surfaceMuted`, por causa do contraste AA. Verde #10B981 em texto sobre branco não passa.
  - "Encerrado": cinza.
- **`EventCard`** ganha o parâmetro opcional `EventStatus? status`. Quem monta a lista calcula o status com `nowProvider`.
- Opcional, se o design pedir: mostrar dia e hora no card, que hoje tem o ícone de calendário sem a data.

### 8.4 Detalhe do evento (`event_detail_page.dart`)

- Usa o **stream do documento** (`watchById`), e assim reflete o encerramento sem precisar invalidar provider.
- **CTA por status:**

  | Status | Quem vê | CTA |
  |---|---|---|
  | Agendado | Quem não participa | "Participar" |
  | Agendado | Participante | "Você está participando" (desabilitado) |
  | Agendado | Criador | "Você organiza este evento" (desabilitado) |
  | Acontecendo | Participante ou criador | Selo + **"Abrir evento ao vivo"** (vai para `/events/:id/ao-vivo`) |
  | Acontecendo | Quem não participa | "Participar" (ainda pode entrar) |
  | Encerrado | Todos | Selo "Encerrado" (ou "Encerrado automaticamente") + "Nota do evento ★ 4,6 · 8 avaliações", se houver |
  | Encerrado | Participante | "Avaliar evento"; para o criador, "Avaliar local e participantes"; depois de avaliar, "Você já avaliou" a partir de `ratedBy` |
  | Encerrado | Quem não participa | Sem CTA |

- Os textos que estão fixos no código vão para `AppStrings`.

### 8.5 Card ao vivo e tela do evento em andamento

- **`lib/features/events/presentation/widgets/live_event_card.dart`:** primeiro sliver da aba Eventos, só se houver evento `happening` em que o usuário participa. Mostra:
  - pílula "AO VIVO" com ponto verde;
  - "Termina às HH:mm";
  - título e "esporte · local";
  - barra de progresso do tempo decorrido;
  - avatares mais a contagem;
  - botão "Abrir evento".
- **Card em atraso** (passou de `endsAt`, ainda dentro da tolerância): a barra fica cheia com "Horário previsto encerrado" na cor `warning`.
- **Página nova `lib/features/events/presentation/pages/live_event_page.dart`**, na rota `/events/:id/ao-vivo` (filha de `:id` no branch 1):
  - **Cabeçalho:** selo, título, "Começou às HH:mm · termina às HH:mm", barra de progresso e "Faltam X min" ou "Passou X min do previsto".
    - Criador em atraso: "O horário previsto acabou. Encerre o evento para liberar as avaliações."
    - Participante em atraso: "O horário previsto acabou. O organizador ainda vai encerrar o evento."
  - **Local:** nome e endereço vindos do `placeSnapshot`.
  - **Participantes (N):** lista com `UserAvatar`, nome e @handle.
    - Tags "Organizador" e "Você".
    - Ícone de mensagem em todos, **menos em você mesmo** (por causa do `idBetween(a == b)`). Ele abre a DM no padrão de `new_conversation_page.dart`.
  - **Participante:** `SecondaryButton` "Falar com o organizador" (DM com `event.creator`).
  - **Criador:** `PrimaryButton` "Encerrar evento", com confirmação:
    - título "Encerrar o evento agora?";
    - corpo "Os participantes vão receber o convite para avaliar. Não dá para desfazer.";
    - ações "Cancelar" e "Encerrar" (cor `error`).
  - **Ao encerrar:**
    - chama `repository.endEvent(id)`, que no remoto faz `update({ endedAt: FieldValue.serverTimestamp(), endedAutomatically: false })` e no mock faz `store.end(id)`;
    - em seguida faz `context.push('/avaliacao/$id')`;
    - em caso de erro, SnackBar. Se a regra negar porque já encerrou, a mensagem é "Este evento já foi encerrado".
  - **Encerrado enquanto aberto** (stream): o participante vê a faixa "O organizador encerrou o evento." com o botão "Avaliar agora".
  - **Quem não participa** e abre a rota é mandado para o detalhe.
- **Novo use case `EndEvent`** e métodos novos no repositório: `endEvent`, `watchById` e `watchJoinedActive`.
- **`PeerAvatar` sobe para `lib/shared/widgets/user_avatar.dart` como `UserAvatar`:** o chat passa a importar de lá, e `ParticipantsAvatars` também passa a usá-lo.

### 8.6 Central de notificações

- **Feature nova `lib/features/notifications/{domain,data,presentation}`:**
  - **domain:** entidade `AppNotification` (com os campos de 5.4) e `NotificationsRepository { Stream<List<AppNotification>> watch(String uid); Future<void> markRead(String uid, String id); Future<void> markAllRead(String uid, Iterable<String> ids); }`, mais use cases finos.
  - **data:** remoto com `users/{uid}/notifications`, `orderBy('createdAt', descending: true).limit(50).snapshots()` e `update({'readAt': FieldValue.serverTimestamp()})` (batch no "marcar todas"), mais um `InMemoryNotificationsStore` para o mock.
- **No mock**, `InMemoryEventsStore.end()` deve criar as notificações, fazendo o papel do gatilho.
- **Providers:** `notificationsProvider` (stream do uid atual) e `unreadNotificationsCountProvider`.
- **Sino:** `GreetingHeader` ganha `unreadNotifications` (int) e `onNotificationsTap`.
  - Fica um `IconButton` com `Icons.notifications_outlined` e badge vermelho (`error`, "9+" a partir de 10) **ao lado da engrenagem**.
  - Semântica: "Notificações, N não lidas".
  - **Mantenha "COMPY" centralizado:** com dois ícones à direita, use `Stack` ou um espaço simétrico à esquerda.
  - A `HomePage` passa `context.push(AppRoutes.notifications)`.
- **Página nova `lib/features/notifications/presentation/pages/notifications_page.dart`**, na rota **`/home/notificacoes`** (`AppRoutes.notifications`):
  - AppBar "Notificações" com a ação "Marcar todas como lidas";
  - seções "Novas" e "Anteriores";
  - cada item tem círculo com o ícone e a cor do esporte, título, corpo, tempo relativo ("há 2 h") e ponto de não lida;
  - itens concluídos mostram a etiqueta "Avaliado ✓";
  - **ao tocar:** marca como lida e navega para `/avaliacao/:eventId`, ou para o detalhe se já avaliou;
  - estado vazio com ícone de sino, "Nada por aqui ainda" e "Quando um evento de que você participou terminar, o convite para avaliar aparece aqui."
- **Diálogo único (D5):**
  - `_ScaffoldWithNavBar` vira `ConsumerStatefulWidget`.
  - **Na primeira emissão** do `notificationsProvider` depois que o app abre (guarde uma flag), procure notificações `eventEnded` com `endedAutomatically && creatorId == eu && readAt == null`.
  - Para a primeira encontrada, mostre o `AlertDialog`:
    - título "Seu evento foi encerrado automaticamente";
    - corpo "O {título} passou 1h do horário previsto e encerramos por você. Que tal avaliar o local e quem jogou?";
    - ações "Agora não" e "Avaliar".
  - **Marque `readAt` ao mostrar.** "Avaliar" faz `push('/avaliacao/:eventId')`.
  - Emissões seguintes não abrem o diálogo; elas só aparecem no badge.
- **Exclusão de conta:** `_deleteUserDocuments` lista `users/{uid}/notifications` e inclui os deletes no mesmo batch.

### 8.7 Fluxo de avaliação

- **Feature nova `lib/features/ratings/{domain,data,presentation}`:**
  - **domain:**
    - `RatingSummary`, **movido** de `profile/domain/entities` (atualize os imports), com o construtor novo `RatingSummary.fromAggregate(count, sum, starCounts)`;
    - `RatingDraft { int? stars; String comment; bool skipped }`;
    - `RatingValidation`, pura: sem estrelas → "falta nota" (só no evento e no local); comentário sem estrelas → impossível pela UI, mas validado; nota abaixo de 3 sem comentário aparado → erro; mais de 500 caracteres → erro;
    - `EventRatingSubmission`;
    - `RatingsRepository { Future<void> submit(EventRatingSubmission); Stream<RatingSummary> watchSummary(RatingTargetType type, String id); }`.
  - **data:**
    - remoto: `FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('submitEventRatings')`, mais o stream de `ratingSummaries/{type}_{id}`;
    - o `FirebaseFunctionsException.code` é mapeado para exceções de domínio: `already-exists`, `failed-precondition`, `permission-denied`, `unavailable` (offline) e as demais;
    - o mock usa um `InMemoryRatingsStore`, que calcula os agregados e atualiza `ratedBy` no store de eventos.
- **Dependência nova:** `flutter pub add cloud_functions`. Deve resolver para a linha 5.x, compatível com `firebase_core` 3.15.2; confira.
- **`firebase_service.dart`:** no modo emulador, `FirebaseFunctions.instanceFor(region: 'southamerica-east1').useFunctionsEmulator('localhost', 5001)`.
- **Página `EventRatingPage`** em **tela cheia**:
  - rota **`/avaliacao/:eventId`**, no nível raiz, **fora do shell** e sem a barra inferior. Ela é aberta com `context.push`.
  - **Participante:** passo 1 Evento ("Como foi o evento?"), passo 2 Local ("E o local?"), passo 3 Participantes ("Quem jogou com você", opcional).
  - **Criador:** passo 1 Local, passo 2 Participantes.
  - Evento legado sem `placeId` pula o passo do local. Sem outros participantes, pula o passo de participantes.
  - **Topo:** "X" para fechar, com confirmação "Sair sem enviar?" se houver algo preenchido, e progresso "Passo i de n".
  - **Bloco de nota:**
    - 5 estrelas grandes, com alvo de toque de pelo menos 48px e semântica "N de 5 estrelas";
    - rótulo embaixo (Péssimo, Ruim, Ok, Bom, Excelente);
    - **o campo de comentário fica desabilitado até escolher as estrelas** ("Escolha as estrelas para comentar");
    - abaixo de 3, a dica vira "Por que essa nota?" e, sem texto, mostra o erro "Para notas abaixo de 3, conte o motivo.";
    - nota fixa "Seu comentário não fica público: só a média aparece.";
    - "Continuar" fica desabilitado até o passo estar válido.
  - **Passo de participantes:**
    - um card por pessoa com avatar, nome, @handle e a tag "Organizador";
    - estrelas, comentário e "Pular". Card pulado vira "Pulado · Desfazer";
    - "Pular todas" no topo;
    - card sem estrelas conta como não avaliado;
    - o envio só fica bloqueado se algum card com nota abaixo de 3 estiver sem comentário;
    - a própria pessoa nunca aparece na lista.
  - **Envio:**
    - "Enviar avaliação" com loading, depois a tela de sucesso "Avaliação enviada!" / "Obrigado por ajudar a comunidade do COMPY." com o botão "Voltar";
    - erros em SnackBar com texto de `AppStrings`;
    - `already-exists` mostra "Você já avaliou este evento" e fecha o fluxo.
- **Pontos de entrada:**
  - "Encerrar evento", só para o criador;
  - a notificação;
  - o detalhe do evento encerrado;
  - o diálogo de encerramento automático.

### 8.8 Médias

- **Perfil:**
  - `ProfilePage` lê `ratingSummaryProvider((user, uid))` em tempo real;
  - **remova `UserProfile.rating`**: ajuste o mock, o repositório e os 3 testes da seção 4.4. O mock de 4.8/12 vai para o `InMemoryRatingsStore`.
- **`RatingBreakdown`:**
  - vírgula decimal (`NumberFormat('0.0', 'pt_BR')` → "4,8");
  - estrelas pelo `StarRating` de exibição;
  - `AppStrings.ratingsCount(n)` → "1 avaliação" / "12 avaliações";
  - o estado vazio continua em primeira pessoa **só** no perfil próprio;
  - **o `rating_breakdown_test.dart` muda** junto.
- **`PlaceDetailsSheet`:**
  - um widget `PlaceRatingRow` (ConsumerWidget) logo abaixo de `_SportsWrap`, que lê `ratingSummaryProvider((place, id))`;
  - mostra "★★★★☆ 4,3 (23 avaliações)" ou, em cinza, "Sem avaliações ainda";
  - use o `_RatingRow` antigo como referência visual.
- **Detalhe do evento encerrado:** "Nota do evento" com a média e a contagem do `ratingSummaries/event_{id}`.
- **Nenhum comentário aparece em lugar nenhum** (D13).
- **Widget compartilhado `lib/shared/widgets/star_rating.dart`:** modo exibição (`value`, `size`) e modo entrada (`value`, `onChanged`, `size`, semântica).

### 8.9 Rotas novas (`lib/core/routes/app_router.dart`)

| Constante | Caminho | Onde |
|---|---|---|
| `AppRoutes.notifications` | `/home/notificacoes` | branch 0, filha de `/home` |
| `AppRoutes.liveEvent` (helper `liveEventPath(id)`) | `/events/:id/ao-vivo` | branch 1, filha de `:id` |
| `AppRoutes.eventRating` (helper `eventRatingPath(id)`) | `/avaliacao/:eventId` | rota raiz, fora do shell (tela cheia) |

Acrescente as três na lista `rotasDoApp` de `test/core/routes/auth_redirect_test.dart`. O `authRedirect` não precisa mudar, mas confira que usuário completo em `/avaliacao/x` não é redirecionado.

### 8.10 Textos (todos em `AppStrings`; ajuste fino depois do design)

- **Status:**
  - `eventStatusLive` = "Acontecendo agora"
  - `eventStatusEnded` = "Encerrado"
  - `eventStatusEndedAutomatically` = "Encerrado automaticamente"
- **Card ao vivo:**
  - "AO VIVO"
  - "Termina às {HH:mm}"
  - "Horário previsto encerrado"
  - "Abrir evento"
- **Tela ao vivo:**
  - "Começou às {HH:mm} · termina às {HH:mm}"
  - "Faltam {X}"
  - "Passou {X} do previsto"
  - "O horário previsto acabou. Encerre o evento para liberar as avaliações."
  - "O horário previsto acabou. O organizador ainda vai encerrar o evento."
  - "Participantes ({n})"
  - "Organizador"
  - "Você"
  - "Mandar mensagem"
  - "Falar com o organizador"
  - "Encerrar evento"
  - "Encerrar o evento agora?"
  - "Os participantes vão receber o convite para avaliar. Não dá para desfazer."
  - "Encerrar"
  - "O organizador encerrou o evento."
  - "Avaliar agora"
  - "Não foi possível encerrar o evento. Tente de novo."
  - "Este evento já foi encerrado."
- **Detalhe:**
  - "Você está participando"
  - "Você organiza este evento"
  - "Abrir evento ao vivo"
  - "Avaliar evento"
  - "Avaliar local e participantes"
  - "Você já avaliou"
  - "Nota do evento"
  - "Este evento já terminou"
  - os textos que hoje estão fixos: "Participantes (N)", "Você entrou no evento!", "Evento não encontrado.", "Erro ao entrar no evento"
- **Notificações:**
  - "Notificações"
  - "Marcar todas como lidas"
  - "Novas"
  - "Anteriores"
  - "Nada por aqui ainda"
  - "Quando um evento de que você participou terminar, o convite para avaliar aparece aqui."
  - "Notificações, {n} não lidas"
  - **participante:** título "Como foi o {título}?", corpo "O evento terminou. Avalie o evento, o local e quem jogou com você."
  - **criador, manual:** título "Como foi o {título}?", corpo "Seu evento terminou. Avalie o local e quem jogou com você."
  - **criador, automático:** título "Seu evento foi encerrado automaticamente", corpo "{título} passou 1h do horário previsto. Avalie o local e os participantes."
  - "Avaliado"
- **Diálogo:**
  - "Seu evento foi encerrado automaticamente"
  - "O {título} passou 1h do horário previsto e encerramos por você. Que tal avaliar o local e quem jogou?"
  - "Agora não"
  - "Avaliar"
- **Avaliação:**
  - "Avaliar evento"
  - "Passo {i} de {n}"
  - "Como foi o evento?"
  - "E o local?"
  - "Quem jogou com você"
  - "Opcional"
  - "Pular"
  - "Pular todas"
  - "Pulado"
  - "Desfazer"
  - rótulos Péssimo, Ruim, Ok, Bom, Excelente
  - "Conte o que aconteceu (opcional)"
  - "Por que essa nota?"
  - "Escolha as estrelas para comentar"
  - "Para notas abaixo de 3, conte o motivo."
  - "Seu comentário não fica público: só a média aparece."
  - "Continuar"
  - "Enviar avaliação"
  - "Avaliação enviada!"
  - "Obrigado por ajudar a comunidade do COMPY."
  - "Voltar"
  - "Sair sem enviar?"
  - "O que você preencheu vai se perder."
  - **erros:**
    - "Você já avaliou este evento."
    - "Este evento ainda não terminou."
    - "Só quem participou pode avaliar."
    - "Sem conexão. Tente de novo quando a internet voltar."
    - "Não foi possível enviar a avaliação."
- **Médias:**
  - "1 avaliação" / "{n} avaliações"
  - "Sem avaliações ainda"

### 8.11 Mock e testes Dart

- **`InMemoryEventsStore`:**
  - `add()` gera id quando vier vazio;
  - ganha `end(id, {automatic})`, `watchById(id)`, `watchJoinedActive(uid, notBefore)` e `markRated(id, uid)`.
- **`MockEvents.nearby`:**
  - põe o `u_joao` entre os participantes do `evt_003`;
  - ganha um evento **ao vivo** (começou há 20 min, 1h de duração, com `u_joao` participando);
  - ganha um evento **encerrado** (terminou ontem, com `endedAt`, `u_joao` participando, ainda não avaliado);
  - todas as datas são relativas a `DateTime.now()`.
- **Testes novos:**
  - **unidade:**
    - `event_status_test.dart`, com as bordas: exatamente em `dateTime`, em `endsAt`, em `endsAt + 1h` e com `endedAt` antes do início;
    - `rating_validation_test.dart`;
    - mapeamento do texto das notificações;
    - `RatingSummary.fromAggregate`;
    - filtros do repositório com clock fixo.
  - **widget:**
    - card ao vivo aparece só para participante;
    - "Encerrar" aparece só para o criador;
    - CTA do detalhe por status;
    - fluxo de avaliação: não avança sem estrelas, comentário travado até ter nota, nota abaixo de 3 exige comentário, "Pular todas", criador sem o passo do evento;
    - badge do sino e lista de notificações;
    - o diálogo aparece só uma vez;
    - `RatingBreakdown` mostra "4,8";
    - a linha de nota no `PlaceDetailsSheet`.
- **Sobrescreva** `nowProvider` e `clockProvider` em todo teste de widget que toque nisso.

---

## 9. Fase 1: design no Claude Design (antes de codar telas)

O usuário pediu explicitamente: **"Use o claude design para pensar no design"**.

1. Crie o canvas com a ferramenta **Artifact**:
   - `publish` com `type_url: "https://claude.ai/artifact/QKN21svewxgyPb6SYRqWnd"` (tipo "Design"), `title: "COMPY — Ciclo de vida do evento"` e `auto_open: "after_first_write"`, sem arquivos;
   - se o `type_url` não funcionar, rode `Artifact action=quickstart intent=design`;
   - siga as instruções que a criação devolve (como preencher as pranchas). A conta **não tem design system**, então construa com os tokens do app.
2. **Tokens:**
   - fonte Inter;
   - cores `#1F3A8A` (primária), `#10B981` (verde/ao vivo), `#F1F1F4` (superfície), `#6B7280` (texto secundário), `#E2E2E5` (borda), `#F59E0B` (estrelas), `#DC2626` (erro) e `#0A0A0A` (texto);
   - pílulas de raio 20 a 32 e cards de raio 12 a 16;
   - telas de **390×844**.
   - Referência visual do app atual: `docs/assets/screenshots/{home,eventos,evento-detalhe,perfil,chat,mapa}.jpg`. O visual é branco e limpo, com pílulas cinza-claro e CTA azul-escuro.
3. **Pranchas** (com textos reais da seção 8.10):
   1. Home com o **sino** e o badge ao lado da engrenagem, com "COMPY" centralizado.
   2. Central de notificações: itens não lidos, lidos e "Avaliado ✓", mais o estado vazio.
   3. Aba Eventos com o **card ao vivo** no topo e o selo "Acontecendo agora" num `EventCard`.
   4. Tela ao vivo na visão do **participante**, com "Falar com o organizador" e mensagem por pessoa.
   5. Tela ao vivo na visão do **criador** em atraso, com o aviso e "Encerrar evento", mais o **diálogo de confirmação**.
   6. Avaliação, passo **Evento**, mostrando o estado de erro de nota abaixo de 3 sem comentário.
   7. Avaliação, passo **Local**.
   8. Avaliação, passo **Participantes**: cards com Pular e "Pulado · Desfazer", mais "Pular todas".
   9. Avaliação **concluída**.
   10. **Diálogo** "Seu evento foi encerrado automaticamente".
   11. Detalhe do evento **encerrado** antes de avaliar ("Avaliar evento") e depois ("Você já avaliou"), com a nota do evento.
   12. **Perfil** com a seção Avaliações real ("4,8", barras, "12 avaliações") e a **ficha do local** com a linha de nota.
4. Cuide do **contraste AA**: texto do selo escuro, verde só no ponto, estrelas com contorno visível.
5. **Ponto de parada:**
   - mande o link ao usuário e pergunte (AskUserQuestion) se aprova ou o que ajustar;
   - **só codifique as telas (tickets 06, 07, 09, 11 e 13, e os que dependem deles) depois do ok**;
   - os tickets 02 a 05, que não mudam o visual, podem andar antes.

---

## 10. Fase 2: tickets

> **Atualizado em 21/10/2026:** a quebra final, aprovada pelo usuário, tem **15 tickets** em `.scratch/ciclo-vida-evento/issues/`. O `.scratch/ciclo-vida-evento/spec.md` mapeia a numeração antiga para a nova e explica o que mudou: a avaliação vem antes da central de notificações, e os tickets grandes foram divididos. A tabela e os critérios abaixo são a proposta original e ficam como referência de conteúdo. **Os números desta seção são os antigos.**

**Fase 0 (antes do ticket 01, feita em 21/10/2026):**
1. `git switch develop && git switch -c feature/ciclo-vida-evento`.
2. Crie `.scratch/ciclo-vida-evento/spec.md`, que só **aponta para este documento** (não duplique o conteúdo), e `.scratch/ciclo-vida-evento/issues/01-...md` a `08-...md` no formato dos tickets do admin (`.scratch/admin-panel/issues/02-...md`):
   - `# NN: <título>`;
   - linhas `Status: open`, `Blocked by: ...` e `Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §...`;
   - `**What to build:**`;
   - `## Acceptance criteria` com `- [ ]`;
   - `## Verification`.
   - O corpo é em PT-BR e os títulos das seções ficam em inglês.
3. Primeiro commit: `docs: plano e tickets da tarefa 14 (ciclo de vida do evento)`. Ele leva este documento, o `.scratch/ciclo-vida-evento/` e a nota no caderno.

| # | Ticket | Bloqueado por | Arquivos principais | Commit sugerido |
|---|---|---|---|---|
| 01 | **Status do evento** (8.1 + correções do mock 8.11) | nenhum | `lib/shared/models/event.dart`, novo `event_status.dart`, novo `lib/core/providers/clock_providers.dart`, `in_memory_events_store.dart`, `mock_events.dart`, `create_event_page.dart`, testes | `feat: status derivado do evento (agendado, acontecendo, encerrado)` |
| 02 | **Listas sem encerrados e selo** (8.2, 8.3, 8.4 + regra do join) | 01, design | `events_remote_datasource.dart`, `events_repository_impl.dart`, `events_repository.dart`, `events_providers.dart`, `home_remote_datasource.dart` e o repositório/providers da Home, `search` no repositório, `event_card.dart`, novo `event_status_chip.dart`, `event_detail_page.dart`, `firestore.rules` (create e join), `events.test.js` | `feat: listas escondem eventos encerrados e mostram selo acontecendo agora` |
| 03 | **Evento ao vivo e encerrar** (8.5 + regras de encerrar e de proteção) | 01, 02 | novo `live_event_card.dart`, novo `live_event_page.dart`, `events_list_page.dart`, use case `end_event.dart`, repositório e datasource, `app_router.dart`, novo `lib/shared/widgets/user_avatar.dart` (o chat passa a usar), `firestore.rules`, `events.test.js`, `auth_redirect_test.dart` | `feat: card e tela do evento ao vivo com encerrar pelo criador` |
| 04 | **Encerramento automático** (6.1, 6.4) | 01 | `functions/src/event_lifecycle.ts`, `functions/src/index.ts`, `functions/test/event_lifecycle.test.ts`, `functions/test/config.test.ts`, `firebase.json` | `feat: function agendada encerra eventos esquecidos` |
| 05 | **Central de notificações** (6.2, 7, 8.6) | 03, 04 | `functions/src/event_notifications.ts` + teste, `firestore.rules` (notifications), novo `notifications.test.js`, `lib/features/notifications/**`, `greeting_header.dart`, `home_page.dart`, `app_router.dart` (rota e `_ScaffoldWithNavBar`), `auth_remote_datasource.dart` (exclusão de conta) | `feat: central de notificacoes com aviso de evento encerrado` |
| 06 | **Avaliação** (6.3, 7, 8.7) | 03, 05 | `functions/src/event_ratings.ts` + teste, `firestore.rules` (ratings e ratingSummaries), novo `ratings.test.js`, `pubspec.yaml` (`cloud_functions`), `firebase_service.dart`, `lib/features/ratings/**`, `app_router.dart`, os pontos de entrada (tela ao vivo, notificações, detalhe, diálogo) | `feat: avaliacao de evento, local e participantes via cloud function` |
| 07 | **Médias reais** (8.8) | 06 | `profile_page.dart`, `user_profile.dart`, `profile_repository_impl.dart`, `mock_profile.dart`, `rating_breakdown.dart` + teste, `place_details_sheet.dart`, `event_detail_page.dart`, `lib/shared/widgets/star_rating.dart`, os 3 testes que usavam `UserProfile.rating` | `feat: medias reais de avaliacao no perfil, no local e no evento` |
| 08 | **Fechamento** (11, 12) | todos | `docs/roadmap.md`, novo `docs/adr/0002-ciclo-de-vida-e-avaliacoes-com-cloud-functions.md`, `CONTEXT.md`, `README.md`, `docs/admin/firebase-deployment.md`, `tools/firestore-rules-tests/README.md` | `docs: fecha a tarefa 14 no roadmap, adr 0002 e readme` |

**Critérios de aceite por ticket** (resumo; detalhe nas seções 6 a 8):
- **01**
  - `statusAt` está correto nas bordas;
  - `Event` lê os três campos novos e o `toMap` não os grava;
  - o mock tem eventos ao vivo e encerrado coerentes;
  - o formulário não aceita início no passado;
  - `flutter test` e `dart analyze` verdes.
- **02**
  - nenhum evento encerrado aparece em "Todos", "Criados por mim", "Participando", na Home ou na busca;
  - "Todos" não trava com página filtrada vazia;
  - o selo aparece em evento acontecendo;
  - o detalhe mostra o CTA certo por status e papel, o que corrige o "Participar" para quem já participa;
  - a regra nega join em evento encerrado;
  - a suíte de regras está verde, com as fixtures datadas relativas a agora.
- **03**
  - o card ao vivo aparece só para participantes, inclusive o criador, e não depende do filtro da aba;
  - "Encerrar" aparece só para o criador, pede confirmação e grava `endedAt` pelo servidor;
  - a regra só deixa o criador encerrar uma vez, depois do início e dentro de `endsAt + 1h`, sem mexer em `ratedBy` nem pôr `endedAutomatically = true`;
  - as DMs abrem a conversa 1:1 certa, sem botão para si mesmo;
  - o participante vê a faixa "encerrado" em tempo real.
- **04**
  - a Function encerra só eventos vencidos e abertos, com `endedAt = endsAt + 1h` e `endedAutomatically = true`;
  - é idempotente;
  - os testes com fakes e o teste de região estão verdes;
  - `npm run lint` e `npm test --prefix functions` verdes.
- **05**
  - encerrar (manual ou automático) cria uma notificação por participante, sem duplicar na reentrega;
  - o sino mostra o número de não lidas;
  - a página lista, marca como lida e navega;
  - o criador com encerramento automático vê o diálogo **uma única vez** ao abrir o app;
  - excluir a conta apaga as notificações;
  - as regras de notifications estão verdes.
- **06**
  - não dá para concluir sem avaliar evento e local (o criador, sem o evento);
  - não dá para comentar sem estrelas;
  - nota abaixo de 3 sem justificativa é bloqueada nos três alvos, na UI e no servidor;
  - a gravação é atômica, sem duplicidade (`already-exists`);
  - `ratedBy` e a notificação viram "Avaliado";
  - `ratings` está fechada ao cliente.
- **07**
  - as médias reais aparecem no perfil (com vírgula decimal e plural certo), na ficha do local e no detalhe do evento encerrado;
  - nenhum comentário aparece;
  - os testes ajustados estão verdes.
- **08**
  - documentação atualizada;
  - E2E no Chrome concluído (11.3);
  - merge local feito;
  - deploy feito e conferido (12).

**Em todo ticket:** um bullet no caderno do dia, no mesmo commit, e o ticket do `.scratch` vai para `Status: resolved`, com a Verification preenchida.

---

## 11. Verificação

### 11.1 Automática (antes de cada commit)

```bash
flutter test
dart analyze                      # 0 erros; sem infos novas além das 10 que já existiam
npm run lint --prefix functions
npm test --prefix functions       # build + node --test
# Regras (Git Bash):
export JAVA_HOME="/c/Users/gabri/.jdks/temurin-25.0.3"; export PATH="$JAVA_HOME/bin:$PATH"
npm test --prefix tools/firestore-rules-tests
```

No PowerShell, em vez do `export`:

```powershell
$env:JAVA_HOME = "$env:USERPROFILE\.jdks\temurin-25.0.3"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Se o sandbox der erro de loopback do Java, rode o comando fora do sandbox.

### 11.2 Ambiente E2E (Chrome com emuladores; nunca toca o `compy-tcc`)

```bash
npm run build --prefix functions
# terminal 1 (em background), com JAVA_HOME do JDK 25 como acima:
firebase emulators:start --only auth,firestore,functions --project compy-tcc
# terminal 2 (em background):
flutter run -d web-server --web-port 8686 --dart-define=USE_FIREBASE_EMULATORS=true
```

- Abra `http://localhost:8686` numa **aba nova** pela extensão claude-in-chrome. Comece com `tabs_context_mcp`.
- **O Flutter web desenha em canvas.** Para `find` e `read_page` enxergarem os elementos, ligue a semântica: rode via `javascript_tool` o `document.querySelector('flt-semantics-placeholder')?.click()`. Também dá para usar captura de tela e clique por coordenada.
- **Não dispare `alert()` do navegador.**
- **Semear um local ativo** no emulador. A regra de `places` exige admin, por isso a REST usa `Bearer owner`, que pula as regras. O contrato é estrito; veja 4.4.

```bash
curl -s -X POST "http://127.0.0.1:8080/v1/projects/compy-tcc/databases/(default)/documents/places?documentId=quadra_teste" \
  -H "Authorization: Bearer owner" -H "Content-Type: application/json" \
  -d '{"fields":{
    "name":{"stringValue":"Quadra de Teste"},
    "nameLower":{"stringValue":"quadra de teste"},
    "description":{"stringValue":"Quadra poliesportiva usada apenas nos testes locais."},
    "address":{"mapValue":{"fields":{"street":{"stringValue":"Rua Central"},"city":{"stringValue":"Taquara"},"cityLower":{"stringValue":"taquara"},"state":{"stringValue":"RS"}}}},
    "sports":{"arrayValue":{"values":[{"stringValue":"futebol"},{"stringValue":"basquete"}]}},
    "primarySport":{"stringValue":"futebol"},
    "coordinates":{"geoPointValue":{"latitude":-29.6505,"longitude":-50.7808}},
    "imageUrl":{"stringValue":"https://images.unsplash.com/photo-1574629810360-7efbbe195018"},
    "status":{"stringValue":"active"},
    "createdAt":{"timestampValue":"2026-01-01T00:00:00Z"},
    "updatedAt":{"timestampValue":"2026-01-01T00:00:00Z"}}}'
```

- **Contas:** crie pela tela de cadastro, com e-mail e senha, as contas A (criador), B (participante) e C (fora do evento). Cada uma passa por username e esportes favoritos. Para trocar de conta, saia e entre de novo.

### 11.3 Roteiro E2E

1. **A cria o evento:** começa daqui a cerca de 2 min, dura 15 min (o mínimo do formulário) e fica na Quadra de Teste. **B entra** no evento.
2. **Ao começar:** o card ao vivo e o selo aparecem para A e B. **C não vê** o card, mas vê o selo em "Todos".
3. **B** abre a tela ao vivo, toca em "Falar com o organizador" e a DM com A abre.
4. **A** encerra o evento, confirma e cai na avaliação **Local → Participantes**. Confira:
   - nota abaixo de 3 sem comentário bloqueia;
   - o comentário fica travado sem estrelas;
   - o envio dá certo.
5. **B** recebe a notificação, com o contador no sino.
   - Ao tocar, abre a avaliação **Evento → Local → Participantes**.
   - Depois de enviar, a notificação vira "Avaliado" e o detalhe mostra "Você já avaliou".
6. **O evento some** de "Todos", "Criados por mim", "Participando", da Home e da busca. O detalhe, aberto pela notificação, mostra "Encerrado" e a nota do evento.
7. **As médias aparecem** no perfil de A (média das notas de B) e na ficha da Quadra de Teste. **Nenhum comentário aparece.**
8. **Encerramento automático (simulado):**
   - A cria um evento que começa daqui a cerca de 2 min.
   - Depois que ele começar, grave `endedAt`/`endedAutomatically` pela REST:

     ```bash
     curl -s -X PATCH "http://127.0.0.1:8080/v1/projects/compy-tcc/databases/(default)/documents/events/<ID>?updateMask.fieldPaths=endedAt&updateMask.fieldPaths=endedAutomatically" \
       -H "Authorization: Bearer owner" -H "Content-Type: application/json" \
       -d '{"fields":{"endedAt":{"timestampValue":"<ISO-UTC>"},"endedAutomatically":{"booleanValue":true}}}'
     ```

   - Isso dispara o gatilho `onEventEnded` de verdade no emulador.
   - A recarrega o app e vê o **diálogo uma única vez**. "Avaliar" leva ao fluxo. Ao recarregar de novo, o diálogo não aparece.
9. **Regressões:**
   - login e logout;
   - criar evento;
   - filtros da aba Eventos;
   - chat;
   - perfil (editar esportes);
   - mapa e ficha do local.

---

## 12. Git, caderno, merge e deploy

- **Branch:** `feature/ciclo-vida-evento`, criada a partir da `develop`. Feature nova **nunca** vai direto em `develop`.
- **Commits:**
  - Conventional Commits em **PT-BR, minúsculo e sem acento**, por exemplo `feat: ...`, `fix: ...`, `docs: ...`;
  - corpo explicando o porquê, como nos commits recentes do repo;
  - **sem** `Co-Authored-By` e sem assinatura;
  - antes de commitar, releia a mensagem.
- **`git add` sempre por arquivo.** **Nunca** adicione `android/app/google-services.json` nem `lib/firebase_options.dart`.
- **Caderno de campo:**
  - um arquivo por dia, `docs/caderno_de_campo/AnotacoesMMDDYYYY.md`, que começa com "Taquara, DD de Mês de AAAA";
  - um bullet `- ` por ticket, em PT-BR simples e na primeira pessoa do plural ("Hoje fizemos...");
  - explica o quê e o porquê, sem lista de arquivos;
  - **vai no mesmo commit do ticket**.
- **Merge, no fim:** `git switch develop && git merge --no-ff feature/ciclo-vida-evento -m "merge: feature/ciclo-vida-evento em develop"`. **Não faça push.**
- **Deploy**, autorizado e feito a partir da `develop` já com o merge, **só com tudo verde**:

  ```bash
  firebase deploy --only firestore:indexes --project compy-tcc        # se firestore.indexes.json mudou
  firebase deploy --only functions:administrative --project compy-tcc  # sobe as 3 novas e redeploya as do admin
  firebase deploy --only firestore:rules --project compy-tcc
  firebase functions:list --project compy-tcc
  firebase functions:log --only autoEndOverdueEvents --project compy-tcc
  ```

  - **Ordem:** Functions antes das regras.
  - **Compatibilidade:** as regras novas funcionam com o **app v0.1.0 já instalado**, que não grava os campos novos, não avalia e não encerra eventos. O app novo (APK) precisa ser gerado e distribuído depois pelo usuário, e isso fica fora desta tarefa.
  - **Gatilho gen2:** o primeiro deploy de gatilho Firestore gen2 pode falhar enquanto a permissão do Eventarc propaga. Espere alguns minutos e repita.
  - **APIs:** o CLI ativa o Cloud Scheduler e o Eventarc sozinho.
  - **Rollback:**
    - regras: publique a versão anterior com `git show <commit>:firestore.rules`;
    - Functions: `firebase functions:delete autoEndOverdueEvents onEventEnded submitEventRatings --region southamerica-east1 --project compy-tcc`.
- **Registro:** anote no caderno e no `docs/admin/firebase-deployment.md` o que foi publicado e o resultado.

---

## 13. Hipóteses a confirmar antes de codar

A revisão crítica foi interrompida. Valide cada item no código ou no teste, e se algum falhar, ajuste o desenho e registre.

1. **Regras de tempo:** `resource.data.get('endsAt', resource.data.dateTime + duration.value(60,'m'))` e `plannedEnd() + duration.value(1,'h')` funcionam no emulador, inclusive com documento legado sem `endsAt`.
2. **`serverTimestamp` nas regras:** com o SDK web usado pela suíte (`updateDoc(..., { endedAt: serverTimestamp() })`), `request.resource.data.endedAt == request.time` é verdadeiro.
3. **`changed()` em bloco aninhado:** o helper global funciona dentro de `match /users/{userId}/notifications/{id}`, que é um bloco aninhado.
4. **`cloud_functions` resolve com Dart 3.13** e com `firebase_core` 3.15.2. `useFunctionsEmulator('localhost', 5001)` funciona na web.
5. **`FieldValue.increment` aninhado:** dentro de `tx.set(..., {merge: true})` em mapa aninhado (`starCounts.N`), soma em vez de sobrescrever. Confira com um teste no emulador ou com a documentação.
6. **Gatilho no emulador:** o emulador de Functions dispara `onDocumentUpdated` em escrita feita pela REST com `Bearer owner`.
7. **Shell:** converter `_ScaffoldWithNavBar` em `ConsumerStatefulWidget` não quebra o `goBranch` nem a preservação de estado das abas.
8. **Rota fora do shell:** `context.push('/avaliacao/:id')` de dentro do shell abre em tela cheia e volta com `pop()` para onde estava. O `authRedirect` não interfere.
9. **Performance:** o `nowProvider` atualizando a cada 30s não reconstrói a lista inteira à toa. Use `select` ou calcule o status no widget folha.
10. **Eventos legados:**
    - os anteriores à tarefa 12, sem `participantIds`, não aparecem no card ao vivo (a consulta é por `participantIds`). Isso é aceitável, mas confira;
    - os sem `placeId` pulam o passo do local.
11. **Contraste AA:** as cores novas do selo, das estrelas de entrada e do badge passam no contraste. Se precisar de uma cor nova, crie com nome e teste, sem mudar as existentes.

---

## 14. Riscos

- **Relógio:** diferença de horário entre o celular e o servidor perto de `endsAt + 1h`. A regra pode negar o encerramento manual; o app mostra "Este evento já foi encerrado" e a Function encerra.
- **Paginação:** filtrar no cliente pode encurtar páginas. O laço em `loadMore` mitiga.
- **`ratedBy` público:** ele expõe quem avaliou (não o quê) para qualquer logado. Isso é aceito; registre na ADR.
- **Dados de conta excluída:** avaliações e médias de quem excluiu a conta continuam existindo, para manter as médias íntegras. As notificações dessa pessoa são apagadas na exclusão.
- **Deploy:** primeiro gatilho gen2 e Eventarc, e o Scheduler; veja a seção 12.
- **Sandbox:** emulador do Firestore com erro de loopback do Java dentro do sandbox; rode fora.

---

## 15. Critérios de aceite finais (roadmap §14, atualizados)

- [x] Eventos encerrados somem de "Todos os eventos", e também de "Criados por mim", "Participando", da Home e da busca (D17).
- [x] Participante de evento em andamento vê o card no topo da aba Eventos; quem não participa, não vê.
- [x] Só o criador vê "Encerrar evento".
- [x] Evento esquecido encerra 1h depois do fim previsto (Function), e o criador é avisado **uma única vez** ao reabrir o app.
- [x] A central de notificações (sino na Home) avisa os participantes quando o evento termina e leva à avaliação (D15).
- [x] Não é possível concluir a avaliação sem avaliar evento e local. O criador avalia local e participantes, não o próprio evento (D14).
- [x] Não é possível enviar comentário sem estrelas, nem nota abaixo de 3 sem justificativa, nos três alvos (UI e servidor).
- [x] As médias aparecem no perfil e na tela do local (e no evento encerrado). Os comentários não aparecem em lugar nenhum (D13).
- [x] O atalho de chat da tela ao vivo abre conversa 1:1 (D16).
- [x] Testes Dart, Functions e regras verdes; E2E no Chrome feito; documentação, ADR e roadmap atualizados; deploy feito e conferido.

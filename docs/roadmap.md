# Roadmap — COMPY

> Criado em 2026-08-08, revisado em 2026-08-09 com as decisões de produto.
> **Atualizado em 2026-09-27:** 13 das 14 tarefas de prioridade alta fechadas (conferido no `git log` de `develop` e no código). Resta a tarefa 14.
> Este documento absorveu o antigo `proximos-passos.md`: o que ainda estava pendente nele virou o [Backlog](#backlog--prioridade-média-e-baixa) no fim.

---

## Status — prioridade alta

| # | Tarefa | Branch | Status |
|---|---|---|---|
| 1 | Username limitado + editar nome no pós-Google | `fix/cadastro-username-e-nome` | ✅ Fechada |
| 2 | Descrição (e título) escritos pelo criador | `feature/descricao-e-titulo-evento` | ✅ Fechada |
| 3 | Duração do evento | `feature/duracao-evento` | ✅ Fechada |
| 4 | Página de insígnias | `feature/atalho-do-perfil-e-telas-em-construcao` | ✅ Fechada (versão mínima) |
| 5 | Auditoria do cadastro via Google | `fix/login-google-developer-error` + fixes no onboarding | ✅ Fechada |
| 6 | Pins do mapa voltarem a aparecer | `fix/pins-mapa-locais` | ✅ Fechada |
| 7 | Pin com ícone e cor do primeiro esporte | (dentro de `fix/pins-mapa-locais`) | ✅ Fechada |
| 8 | Ligar a tela de detalhes do local | `feature/tela-detalhes-local` | ✅ Fechada |
| 9 | Chat funcional | 6 branches (`fix/chat-*`, `feature/nova-conversa-handle`, …) | ✅ Fechada |
| 10 | Categorias da Home → aba Eventos com filtro | `feature/filtro-esportes-eventos` | ✅ Fechada |
| 11 | "Ver mais" nas categorias + filtros | `feature/ver-mais-categorias` | ✅ Fechada |
| 12 | Três seções na aba Eventos | `feature/secoes-aba-eventos` | ✅ Fechada — **ajustes pendentes** |
| 13 | Onboarding de esportes favoritos | `feature/onboarding-esportes-favoritos` | ✅ Fechada |
| 14 | Ciclo de vida do evento: durante, pós e avaliação | `feature/ciclo-vida-evento` | ⏳ **Aberta** |

---

## Tarefas fechadas — resumo

**1 · Username + nome pós-Google** — Username limitado em tamanho e formato nos dois fluxos de cadastro. Na tela pós-Google o nome completo ficou editável; o e-mail continua bloqueado.

**2 · Descrição e título do evento** — O criador escreve a descrição (opcional, sem texto automático) e, de quebra, o título (opcional, com fallback).

**3 · Duração do evento** — Campo obrigatório com 1h pré-selecionado. `endsAt` é derivado no model e gravado no Firestore para consulta; a duração aparece nos detalhes.

**4 · Insígnias** — O "Ver mais" abre `/profile/insignias`, uma tela "em construção" (`UnderConstructionPage`), o que o pedido original já aceitava. O grid estático com o catálogo de insígnias não foi feito; fica para quando existir regra de conquista.

**5 · Auditoria do login Google** — Usuário cadastrado não é mais tratado como novo quando a leitura do perfil falha, e o `DEVELOPER_ERROR` do Google passou a ser distinguido de falha transitória.

**6 · Pins do mapa** — Catálogo de locais unificado (mapa e criar evento usam a mesma fonte) e os pins voltaram. A regra e o datasource de `places` foram removidos.

**7 · Pin por esporte** — Pin com ícone e cor do primeiro esporte do local, ponta ancorada na coordenada. O mesmo pin é usado no preview de criar evento e nos detalhes do evento.

**8 · Tela do local** — O `PlaceDetailsSheet` existente foi ligado: "Criar evento" abre o formulário com o local preenchido, "Favoritar" saiu, o card fecha ao tocar no mapa e há botão de voltar.

**9 · Chat** — Mensagens reais com o remetente certo, sala robusta e agrupada por data, conversa nova por handle, contador de não-lidas real, compartilhar local no chat, e regras de `conversations` restritas a membros, com suíte de testes no emulador.

**10 · Filtro por esporte** — As categorias da Home levam à aba Eventos já filtrada, com a consulta feita no Firestore (não no cliente).

**11 · Ver mais / filtros** — "Ver mais" no carrossel e um seletor de filtros dos eventos, acessível pela Home e pela aba Eventos.

**12 · Três seções** — "Criados por mim", "Participando" e "Todos os eventos", com `participantIds` consultável e regras de `events` por papel (o criador edita; os outros só entram com o próprio uid), testadas no emulador. **Funciona, mas vai passar por ajustes** — anotar aqui o que mudar quando for decidido.

**13 · Esportes favoritos** — Contas novas passam por `/onboarding/esportes` antes da Home. Os favoritos ficam em `users/{uid}`, são editáveis pelo perfil e o carrossel da Home passa a segui-los. Junto, o e-mail saiu do documento público de perfil para `users/{uid}/private/contact`, legível só pelo dono (RN-06).

**Do antigo `proximos-passos.md`, também já feitos:** entrar em evento com o uid real, criar evento com o criador real, busca de eventos com debounce, eventos próximos por geolocalização, paginação das listas de eventos e conversas, nova conversa de chat e revisão das regras do Firestore. O débito técnico listado lá (`AuthService` legado, Home usando mock) também foi resolvido.

---

## 14. Ciclo de vida do evento: durante, pós e avaliação

**Branch:** `feature/ciclo-vida-evento` · **Tamanho:** G · **`/to-tickets`: SIM** · **Dependências (3 e 12): ✅ fechadas**

### Objetivo

Um evento hoje só tem "antes". Esta tarefa entrega o "durante" e o "depois": card do evento em andamento, encerramento (manual ou automático) e o fluxo de avaliação.

### O que já está pronto e ajuda

- `endsAt` existe (tarefa 3): é derivado em `Event` e gravado no Firestore.
- `participantIds` e a seção "Participando" existem (tarefa 12). É deles que sai o card do evento em andamento.
- **As regras da coleção `ratings` já estão escritas** em `firestore.rules`: leitura negada, sem update/delete, validação das estrelas e da justificativa abaixo de 3.
- Em `events`, o `TODO(tarefa 14)` já marca onde abrir a exceção do encerramento automático.
- `RatingSummary.hasRatings` e `SportPlace.hasRatings` já tratam o "sem avaliações" na UI. Falta só alimentá-los.
- A suíte de testes de regras (`tools/firestore-rules-tests/`) já está montada para cobrir as regras novas.

### O que falta

- **Eventos passados continuam em "Todos os eventos"**, porque a lista não filtra por `endsAt`. Provavelmente é o primeiro ticket.
- Nenhum campo de encerramento (`endedAt` etc.) nem status.
- Nenhuma tela de "durante" ou de avaliação, e nada grava em `ratings`.

### Corte sugerido para o `/to-tickets`

1. **Status derivado**: `agendado` / `acontecendo` / `encerrado` a partir de `dateTime`, `endsAt` e `endedAt`. Sem UI nova.
2. **Esconder encerrados** de "Todos os eventos" e marcar "Acontecendo agora" no `EventCard`.
3. **Card do evento ao vivo** no topo da aba Eventos + botão "Encerrar" para o criador.
4. **Encerramento automático** + aviso ao criador na volta.
5. **Avaliação**: tela, validações e gravação em `ratings`.
6. **Média real** alimentando o perfil (`RatingBreakdown`) e o local (`PlaceDetailsSheet`).

### Modelagem proposta

Campos novos em `Event`:

| Campo | Tipo | Para quê |
|---|---|---|
| `endedAt` | `Timestamp?` | `null` = não encerrado. Marca o fim real. |
| `endedAutomatically` | `bool` | Distingue encerramento manual do automático (D5). |
| `creatorNotifiedOfAutoEnd` | `bool` | Garante que o aviso apareça **uma vez** só. |

Status derivado no cliente, sem Cloud Function:

- `endedAt != null` → **encerrado**
- `now >= dateTime && now < endsAt + 1h` → **acontecendo** (a hora extra é a tolerância para o criador encerrar)
- `now >= endsAt + 1h` → **encerrado automaticamente**: grava `endedAt` e `endedAutomatically = true` na primeira leitura que perceber, em transação para não gravar duas vezes
- caso contrário → **agendado**

### Comportamento: evento em andamento (D5)

- Card do evento **acima das três seções** da aba Eventos, **somente se o usuário estiver participando**.
- O card leva à tela do evento em andamento: participantes, dados do evento, atalho para o chat.
- **"Encerrar evento" só para o criador.** Encerrar grava `endedAt` e leva direto à avaliação.
- Se o criador esquecer, o evento encerra sozinho 1h após o fim previsto. Ao reabrir o app ele vê "Seu evento foi encerrado automaticamente" e cai **na mesma tela de finalização**. `creatorNotifiedOfAutoEnd` garante que isso aconteça uma vez.
- Presença não distingue "inscrito" de "compareceu" (D6).

### Comportamento: avaliação (D7, D12, D13)

Três alvos: **participantes** (incluindo o organizador), **o evento** e **o local**.

- Avaliar **evento** e **local** é obrigatório. **Participantes** é opcional: botão "Pular" em cada card e "Pular todas as avaliações de participantes" na tela.
- Card de participante/organizador: foto de perfil, nome, 5 estrelas vazias e caixa de comentário.
- **Só estrelas: permitido. Só comentário: nunca.**
- **Abaixo de 3 estrelas, comentário obrigatório, nos três alvos (D12).** Bloquear o avanço com mensagem clara.
- **Comentários não são públicos (D13).** Guardar tudo, exibir só a média.
- Coleção `ratings`: `eventId`, `fromUid`, `targetType` (`user` | `event` | `place`), `targetId`, `stars`, `comment?`, `createdAt`. Id composto por (`fromUid`, `targetType`, `targetId`, `eventId`) para impedir avaliação duplicada.

### 🔒 Regras do Firestore: o que ainda precisa ser decidido

- **`ratings`:** a regra existe, mas falta decidir se `create` exige que o autor tenha participado do evento e que ele esteja encerrado (custa um `get()` por avaliação). Também falta decidir como a média desnormalizada é gravada no alvo (`users/{uid}`, evento, local): sem `read` em `ratings`, o cliente não consegue recalcular a média a partir das avaliações.
- **`events`:** abrir a exceção do `TODO(tarefa 14)`, em que qualquer participante pode gravar `endedAt`/`endedAutomatically` só se `endsAt + 1h` já passou e `endedAt` ainda é nulo. É a regra mais delicada do arquivo; cobrir na suíte do emulador antes de publicar.

### Critérios de aceite

- Eventos encerrados somem de "Todos os eventos".
- Participante de evento em andamento vê o card no topo da aba Eventos; quem não participa, não vê.
- Só o criador vê "Encerrar evento".
- Evento esquecido encerra 1h depois do fim previsto, e o criador é avisado uma única vez ao reabrir o app.
- Não é possível concluir a avaliação sem avaliar evento e local.
- Não é possível enviar comentário sem estrelas, nem nota abaixo de 3 sem justificativa, nos três alvos.
- As médias aparecem no perfil e na tela do local; os comentários não aparecem em lugar nenhum.

### Perguntas em aberto

1. **Quem lembra o usuário de avaliar?** Um pendente que nunca some incomoda; sem lembrete, quase ninguém avalia. Decidir na fatia 5.
2. **Encerramento automático: regra do Firestore ou Cloud Function?** A exceção na regra é grátis mas delicada; a function é limpa mas adiciona infraestrutura ao TCC. Medir as duas na fatia 4.

> O item "Sistema de avaliação entre usuários" do antigo `proximos-passos.md` foi absorvido por esta tarefa.

---

## Backlog — prioridade média e baixa

Itens herdados do antigo `proximos-passos.md` que continuam pendentes, conferidos no código em 2026-09-27. Entram depois da tarefa 14.

| # | Tarefa | Branch sugerida | Tam. | `/to-tickets`? | 🔒 |
|---|---|---|---|---|---|
| A | Avatar real na Home | `fix/avatar-real-home` | P | Não | |
| B | Edição de perfil completa (nome, bio, foto) | `feature/editar-perfil-completo` | M/G | Talvez | 🔒 |
| C | Tela de configurações | `feature/tela-configuracoes` | M | Não | |
| D | Push notifications (FCM) | `feature/push-notifications` | G | Sim | |

### A · Avatar real na Home

O `GreetingHeader` ainda desenha `AppAssets.avatar(userName)`, o placeholder com a inicial do nome, embora `users/{uid}.avatarUrl` exista. O `currentUserSummaryProvider` já expõe o `UserSummary` do usuário logado: basta a Home passar o `avatarUrl` dele para o header.

**Arquivos:** `lib/features/home/presentation/widgets/greeting_header.dart`, `lib/features/home/presentation/pages/home_page.dart`.

### B · Edição de perfil completa

A `EditProfilePage` (`/profile/editar`) hoje mostra o username desabilitado e permite excluir a conta. Os esportes favoritos já são editáveis pela tela própria. Faltam **nome, bio e foto**.

- `ProfileRemoteDataSource` só sabe gravar `favoriteSports`. Falta um `update` geral.
- `bio` já é lida pelo `ProfileRepositoryImpl`, mas nunca é escrita.
- Foto exige Firebase Storage e um seletor de imagem (`firebase_storage` e `image_picker` não estão instalados), com a URL gravada em `users/{uid}.avatarUrl`. Se o volume for grande, vale quebrar com `/to-tickets` em "nome e bio" primeiro e "foto" depois.
- Nome alterado precisa ir também para o Firebase Auth (`updateDisplayName`), como na tarefa 1, senão a saudação da Home diverge.

**🔒 Regras do Firestore — precisa decidir:** o `validProfile()` de `users` só aceita `['id', 'name', 'handle', 'avatarUrl', 'createdAt', 'favoriteSports']`. Gravar `bio` hoje é **recusado**. Decidir o limite de tamanho da bio e incluí-la no `hasOnly`. Se entrar Storage, escrever também as regras do bucket (só o dono grava a própria foto, tamanho e tipo limitados).

### C · Tela de configurações

A engrenagem da Home abre `/home/configuracoes`, que hoje é a `UnderConstructionPage`. Conteúdo previsto: trocar senha (só para contas de e-mail), sair da conta, preferências de notificação (depende do item D) e um atalho para "Excluir conta", que já existe na `EditProfilePage` — reaproveitar em vez de duplicar.

### D · Push notifications (FCM)

Nada instalado ainda. Notificar quando: uma conversa recebe mensagem, alguém entra no seu evento, o evento vai começar, você recebe uma avaliação. Sem backend, disparar push exige Cloud Functions, o que é infraestrutura nova para o TCC. Decidir antes se vale; se sim, quebrar com `/to-tickets`.

---

## Registro de decisões

Continuam valendo. As que tocam a tarefa 14 estão referenciadas acima.

| # | Decisão |
|---|---|
| D1 | "Parcão" é apelido pessoal do Parque do Trabalhador; não aparece na UI. |
| D2 | Descrição do evento é opcional e sem fallback. |
| D3 | Aba Eventos com 3 seções: "Criados por mim", "Participando", "Todos os eventos". Duplicação aceita. |
| D4 | Sem migração de usuários, porque não há usuários reais. |
| D5 | Evento em andamento: card acima das seções, só para participantes; "Encerrar" só para o criador; encerra sozinho 1h após o fim previsto, com aviso ao criador na volta. |
| D6 | Presença não distingue "inscrito" de "compareceu". |
| D7 | Avaliação de participantes (opcional), evento e local (obrigatórios). |
| D8 | Duração obrigatória, 1h pré-selecionado. |
| D9 | No pós-Google o nome é editável, o e-mail não. |
| D10 | A tela de local é o `PlaceDetailsSheet` existente. |
| D11 | "Favoritar" sai da tela de local; "Compartilhar" veio com o chat. |
| D12 | Nota abaixo de 3 estrelas exige justificativa nos três alvos. |
| D13 | Comentários de avaliação não são públicos. |
</content>

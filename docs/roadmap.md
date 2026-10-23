# Roadmap — COMPY

> Criado em 2026-08-08, revisado em 2026-08-09 com as decisões de produto.
> **Atualizado em 2026-10-22:** as 14 tarefas de prioridade alta estão fechadas. O deploy da 14 (regras e Cloud Functions) está registrado em [`admin/firebase-deployment.md`](admin/firebase-deployment.md). O APK novo ainda precisa ser gerado e distribuído.
> Este documento absorveu o antigo `proximos-passos.md`: o que ainda estava pendente nele virou o [Backlog](#backlog--prioridade-média-e-baixa) no fim.
> **Atualizado em 2026-10-22:** visualização de perfis públicos concluída em `feature/perfil-publico-usuarios`.

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
| 14 | Ciclo de vida do evento: durante, pós e avaliação | `feature/ciclo-vida-evento` | ✅ Fechada |

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

**14 · Ciclo de vida do evento** — O evento ganhou o "durante" e o "depois". Durante o evento, o selo "Acontecendo agora" aparece nas listas, e quem participa vê o card ao vivo no topo da aba Eventos e a tela do evento em andamento, com mensagem 1:1 para cada pessoa (D16). Só o Organizador encerra; se ele esquecer, uma Cloud Function agendada encerra o evento 1h depois do fim previsto, e ele recebe um aviso único ao voltar ao app (D5). Encerrados somem das listas, da Home e da busca, e ninguém mais entra neles (D17). O fim do evento gera uma notificação na central nova (o sino ao lado da engrenagem na Home), que leva à avaliação (D15). Participantes avaliam o evento, o local e quem jogou; o Organizador avalia o local e os participantes (D14). A avaliação é gravada por uma callable, que valida as regras D7, D12 e D13 no servidor. As médias aparecem no perfil, na ficha do local e no evento encerrado, sem nenhum comentário. O plano está em [`tarefa-14-ciclo-de-vida-do-evento.md`](tarefa-14-ciclo-de-vida-do-evento.md), e a decisão de usar Cloud Functions, na [ADR 0002](adr/0002-ciclo-de-vida-e-avaliacoes-com-cloud-functions.md).

**Do antigo `proximos-passos.md`, também já feitos:** entrar em evento com o uid real, criar evento com o criador real, busca de eventos com debounce, eventos próximos por geolocalização, paginação das listas de eventos e conversas, nova conversa de chat e revisão das regras do Firestore. O débito técnico listado lá (`AuthService` legado, Home usando mock) também foi resolvido.

---

## Funcionalidade concluída — perfis públicos de outros usuários

**Branch:** `feature/perfil-publico-usuarios` · **Status:** ✅ Concluída em 2026-10-22.

Usuários autenticados podem abrir `users/{uid}` pelo organizador ou pelos participantes de um evento, pelo cabeçalho de uma conversa e pelo resultado da busca de usuários. A tela mostra apenas nome, handle, avatar, biografia existente e esportes favoritos. O botão "Mensagem" usa o fluxo 1:1 existente. Perfis ausentes e falhas de leitura têm estados próprios; o UID do próprio usuário mostra a tela proprietária. A lista rolável do evento mantém todos os participantes identificáveis. As regras do Firestore não precisaram mudar.

---

## Backlog — prioridade média e baixa

Itens herdados do antigo `proximos-passos.md` que continuam pendentes, conferidos no código em 2026-09-27. A tarefa 14 já fechou, então eles são os próximos.

| # | Tarefa | Branch sugerida | Tam. | `/to-tickets`? | 🔒 |
|---|---|---|---|---|---|
| A | ~~Avatar real na Home~~ ✅ feito em `feature/foto-de-perfil` | — | P | Não | |
| B | Edição de perfil completa (nome, bio) — **foto ✅ feita** | `feature/editar-perfil-completo` | M | Não | ✅ fechada |
| C | Tela de configurações | `feature/tela-configuracoes` | M | Não | |
| D | Push notifications (FCM) | `feature/push-notifications` | G | Sim | |

### A · Avatar real na Home — ✅ fechado

Feito junto com a foto de perfil (`feature/foto-de-perfil`): o `GreetingHeader` usa o `avatarUrl` do perfil e só mostra a inicial enquanto o perfil carrega.

### B · Edição de perfil completa — ✅ fechada

A `EditProfilePage` (`/profile/editar`) edita nome completo (até 60 caracteres) e biografia opcional (até 160), com salvamento explícito, aviso de alterações não salvas e repetição após falha. O Firestore recebe `name`, `nameLower` e `bio` por merge; em seguida o nome é sincronizado no Firebase Auth. Como esses serviços não compartilham transação, uma falha no Auth é mostrada como falha e uma nova tentativa conclui a sincronização. Perfil próprio, Home, busca e perfil público são atualizados pelos providers. O username permanece bloqueado, os esportes usam a tela própria e a foto continua no fluxo existente de seleção, recorte e Storage ([detalhes](autenticacao.md#foto-de-perfil-avatarurl)).

`validProfile()` aceita apenas `bio` opcional do tipo texto e com até 160 caracteres, sem mudar o acesso privado. Nomes e fotos copiados para eventos e conversas antigos continuam como snapshots históricos; leituras diretas de perfil mostram os dados atuais. A pendência de CORS para avatar no Chrome e o comando de configuração do bucket estão em [`checklist-publicacao.md`](checklist-publicacao.md); nenhuma configuração foi aplicada ao bucket nesta tarefa.

### C · Tela de configurações

A engrenagem da Home abre `/home/configuracoes`, que hoje é a `UnderConstructionPage`. Conteúdo previsto: trocar senha (só para contas de e-mail), sair da conta, preferências de notificação (depende do item D) e um atalho para "Excluir conta", que já existe na `EditProfilePage` — reaproveitar em vez de duplicar.

### D · Push notifications (FCM)

Nada instalado ainda. Notificar quando: uma conversa recebe mensagem, alguém entra no seu evento, o evento vai começar, você recebe uma avaliação. A tarefa 14 já trouxe a central de notificações in-app e Cloud Functions no projeto (plano Blaze), então o push pode partir das notificações que o gatilho `onEventEnded` já cria. Decidir antes se vale; se sim, quebrar com `/to-tickets`.

---

## Registro de decisões

Continuam valendo. D14 a D17 vieram do planejamento da tarefa 14, em 21/10/2026.

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
| D14 | O Organizador não avalia o próprio evento: avalia o local e os participantes. A nota do evento vem só de quem participou. |
| D15 | A avaliação começa pela central de notificações in-app (o sino na Home), sem seção nova na aba Eventos. |
| D16 | O atalho de chat do evento em andamento é conversa 1:1: "Falar com o organizador" e um botão de mensagem por participante. |
| D17 | Eventos encerrados somem das listas: as três seções da aba Eventos, a Home e a busca. |
</content>

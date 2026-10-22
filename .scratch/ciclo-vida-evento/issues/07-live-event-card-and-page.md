# 07: Card e tela do evento ao vivo

Status: resolved

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 02 — Avatar de Usuário compartilhado; 04 — Eventos encerrados somem das listas e não aceitam mais participantes; 06 — Selo "Acontecendo agora" e CTA do detalhe por status

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §8.5 (menos o encerrar), §8.9 (rota ao vivo) e §8.10 (Card ao vivo, Tela ao vivo).

Hipóteses a conferir (§13): 9 e 10 (eventos anteriores à tarefa 12, sem `participantIds`, não aparecem no card).

**What to build:** Durante o evento, quem participa (inclusive o criador) ganha um atalho para ele.

- **Card ao vivo:** fica no topo da aba Eventos, independente do filtro. Mostra "AO VIVO", "Termina às HH:mm", título, esporte e local, barra de tempo decorrido, avatares e o botão "Abrir evento". Depois do fim previsto, ainda dentro da tolerância, a barra fica cheia com "Horário previsto encerrado".
- **Detalhe:** ganha "Abrir evento ao vivo" para o participante e para o criador.
- **Tela do evento em andamento:**
  - horário e progresso ("Faltam X" ou "Passou X do previsto");
  - o local, vindo do snapshot;
  - a lista de participantes, com as tags "Organizador" e "Você";
  - em cada pessoa, menos você, um botão de mensagem que abre a conversa 1:1 (D16);
  - para o participante, "Falar com o organizador".

  Quem não participa e abre a rota vai para o detalhe.

## Acceptance criteria

- [x] O card ao vivo aparece só para participante de evento acontecendo, inclusive o criador, e não depende do filtro da aba. Quem não participa não vê o card.
- [x] O card e a seção "Participando" vêm de um stream único dos eventos não encerrados do usuário (`watchJoinedActive`, com o mesmo limite inferior do ticket 04). A seção continua aplicando o filtro da aba no cliente.
- [x] No estado em atraso, o card mostra "Horário previsto encerrado" na cor de aviso.
- [x] A rota `/events/:id/ao-vivo` é filha do detalhe, no branch de Eventos, e entra na lista de rotas do teste do `authRedirect`.
- [x] As mensagens 1:1 abrem a conversa certa pelo padrão do chat, com trava contra toque repetido e SnackBar de erro. Nunca há botão de mensagem para si mesmo.
- [x] O detalhe entrega a linha "Acontecendo, participante ou criador → Abrir evento ao vivo" da tabela de CTA.
- [x] Testes de widget:
  - o card aparece só para participante;
  - não há botão de mensagem para si mesmo;
  - quem não participa é redirecionado ao detalhe.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] Resultado das hipóteses 9 e 10 anotado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Hipóteses (§13), conferidas em 21/10/2026:

- **9:** confirmada. A aba só observa se existe card (`liveEventsProvider.select(isNotEmpty)`). Quem se redesenha a cada 30s é o sliver do card e o bloco de horário da tela ao vivo, não as seções.
- **10:** confirmada e aceita. O card vem da consulta por `participantIds`, então eventos anteriores à tarefa 12, sem esse campo, não aparecem nele. Os participantes desses eventos ainda chegam à tela ao vivo pelo detalhe, porque no app o `participantIds` é derivado de `participants`.

Notas:

- A cor `warningText` (#B45309) entrou no `AppColors` aqui, no "Passou X do previsto" da tela ao vivo. No card azul, o aviso de atraso usa o `warning` (#F59E0B), que dá 4,8:1 sobre o azul primário.
- A tela ao vivo também manda para o detalhe quem chega antes do início, porque ela é só para evento acontecendo. Evento encerrado continua abrindo a tela, para o ticket 08 mostrar a faixa de encerrado.
- "Participando" passou a ser derivado do stream (`joinedEventsProvider` aplica o filtro sobre o `joinedActiveEventsProvider`), e o pull-to-refresh invalida o stream.

Commit sugerido: `feat: card e tela do evento ao vivo com mensagem 1:1`

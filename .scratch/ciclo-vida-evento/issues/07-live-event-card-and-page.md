# 07: Card e tela do evento ao vivo

Status: open

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

- [ ] O card ao vivo aparece só para participante de evento acontecendo, inclusive o criador, e não depende do filtro da aba. Quem não participa não vê o card.
- [ ] O card e a seção "Participando" vêm de um stream único dos eventos não encerrados do usuário (`watchJoinedActive`, com o mesmo limite inferior do ticket 04). A seção continua aplicando o filtro da aba no cliente.
- [ ] No estado em atraso, o card mostra "Horário previsto encerrado" na cor de aviso.
- [ ] A rota `/events/:id/ao-vivo` é filha do detalhe, no branch de Eventos, e entra na lista de rotas do teste do `authRedirect`.
- [ ] As mensagens 1:1 abrem a conversa certa pelo padrão do chat, com trava contra toque repetido e SnackBar de erro. Nunca há botão de mensagem para si mesmo.
- [ ] O detalhe entrega a linha "Acontecendo, participante ou criador → Abrir evento ao vivo" da tabela de CTA.
- [ ] Testes de widget:
  - o card aparece só para participante;
  - não há botão de mensagem para si mesmo;
  - quem não participa é redirecionado ao detalhe.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] Resultado das hipóteses 9 e 10 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: card e tela do evento ao vivo com mensagem 1:1`

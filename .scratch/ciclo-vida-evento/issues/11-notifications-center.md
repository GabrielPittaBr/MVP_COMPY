# 11: Central de notificações com o convite para avaliar

Status: open

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 08 — Criador encerra o evento; 09 — Avaliar o evento e o Local Esportivo

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Quem cria notificações, Aviso de encerramento automático), §5.4, §6.2, §7 (notifications), §8.6 (menos o diálogo único), §8.9 (rota) e §8.10 (Notificações).

Hipóteses a conferir (§13):

- 2: `readAt == request.time` na regra;
- 3: `changed()` funciona dentro do bloco aninhado de `users`;
- 6: o gatilho dispara no emulador com escrita pela REST. Se não der para conferir aqui, confira no E2E.

**What to build:** Quando um evento termina, manual ou automaticamente, cada participante recebe uma notificação in-app que leva à avaliação (D15).

- **Gatilho `onEventEnded`:** detecta a transição "sem `endedAt`" → "com `endedAt`" e cria uma notificação por participante, com id determinístico. Se o gatilho for entregue de novo, nada duplica e nenhuma leitura é zerada. A notificação do criador que encerrou manualmente já vem lida, porque ele foi direto avaliar.
- **Texto:** não é gravado no documento. O app monta título e corpo a partir do tipo.
- **Sino:** fica na Home, ao lado da engrenagem, com "COMPY" ainda centralizado. Tem badge vermelho com o número de não lidas ("9+" a partir de 10).
- **Central (`/home/notificacoes`):** separa Novas e Anteriores, tem "Marcar todas como lidas" e estado vazio. Tocar num item marca como lida e abre a avaliação, ou o detalhe se a pessoa já avaliou.
- **"Avaliado ✓":** a callable de avaliação passa a marcar a notificação como concluída, e a lista mostra a etiqueta.
- **Exclusão de conta:** apaga as notificações.

O diálogo do criador fica para o ticket 12.

## Acceptance criteria

- [ ] **Gatilho:**
  - a transição cria N notificações, uma por participante (ou pelos ids legados);
  - updates sem transição (join, `ratedBy`) não criam nada;
  - no encerramento manual, a notificação do criador vem lida;
  - no automático, ela vem não lida;
  - o id é `eventEnded_{eventId}`;
  - a criação ignora "já existe" e nunca usa `set`.
- [ ] O teste de região inclui o gatilho.
- [ ] Callable de avaliação: na mesma transação, se a notificação existe, grava `completedAt` e preenche `readAt` se ele ainda estava vazio. Os testes cobrem os casos com e sem notificação.
- [ ] **Regras:**
  - o dono lê → permite;
  - outro usuário lê → nega;
  - o dono marca `readAt` com `serverTimestamp()` uma vez → permite;
  - mexer em outro campo → nega;
  - marcar de novo → nega;
  - create → nega;
  - o dono apaga → permite;
  - outro usuário apaga → nega.

  O cabeçalho das regras registra que a exclusão de conta também apaga as notificações.
- [ ] **Feature de notificações no app:**
  - entidade;
  - repositório com stream, marcar como lida e marcar todas em lote;
  - mock em memória, em que encerrar no mock cria as notificações, fazendo o papel do gatilho;
  - providers da lista e da contagem de não lidas.
- [ ] O sino tem badge e semântica "Notificações, N não lidas", e "COMPY" continua centralizado.
- [ ] **Central:**
  - Novas e Anteriores;
  - ícone e cor do esporte;
  - tempo relativo;
  - ponto de não lida;
  - "Avaliado ✓";
  - "Marcar todas como lidas";
  - estado vazio.

  A rota entra no teste do `authRedirect`.
- [ ] Os textos de cada tipo e papel do §8.10 (participante, criador com encerramento manual, criador com encerramento automático) são montados no app e testados.
- [ ] A exclusão de conta apaga as notificações no mesmo lote.
- [ ] Testes de widget: badge, lista, e toque que navega e marca como lida.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] `npm run lint --prefix functions` e `npm test --prefix functions` verdes.
- [ ] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [ ] Resultado das hipóteses 2, 3 e 6 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: central de notificacoes com convite para avaliar`

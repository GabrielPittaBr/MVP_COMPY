# 08: Criador encerra o evento

Status: open

Blocked by: 07 — Card e tela do evento ao vivo

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §5.1, §7 (`isManualEnd` e update de `events`), §8.5 (Encerrar) e §8.10 (Tela ao vivo).

Hipóteses a conferir (§13): 1 e 2 (`serverTimestamp()` igual a `request.time` na regra).

**What to build:** Só o criador vê "Encerrar evento" na tela ao vivo.

- **Encerrar:** ele confirma num diálogo ("Encerrar o evento agora?", "Os participantes vão receber o convite para avaliar. Não dá para desfazer.", "Cancelar" e "Encerrar" em vermelho). O app grava o fim com o horário do servidor e `endedAutomatically = false`.
- **Atraso:** quando o horário previsto passou, a tela avisa. O criador lê "Encerre o evento para liberar as avaliações"; o participante lê que o organizador ainda vai encerrar.
- **Participante com a tela aberta:** vê, em tempo real, a faixa "O organizador encerrou o evento.".
- **Regras:** passam a proteger o ciclo de vida. O criador encerra uma única vez, depois do início e dentro da tolerância, e não mexe mais no evento depois de encerrado.

Enquanto o ticket 09 não existe, depois de encerrar o criador vai para o detalhe do evento já encerrado, e a faixa do participante fica sem botão. O 09 liga os dois à avaliação.

## Acceptance criteria

- [ ] "Encerrar evento" aparece só para o criador, com confirmação. Erro aparece em SnackBar; se a recusa for porque o evento já está encerrado, a mensagem é "Este evento já foi encerrado.".
- [ ] Existe o use case de encerrar e o método no repositório. No Firestore, ele grava `endedAt` pelo servidor e `endedAutomatically = false`. No mock, encerra no store; o papel do gatilho de notificações no mock entra no 11.
- [ ] Criador e participante veem os avisos de atraso. O participante vê a faixa de encerrado em tempo real.
- [ ] Regras:
  - criador encerra evento em andamento com `serverTimestamp()` → permite;
  - visitante encerra → nega;
  - criador encerra antes do início → nega;
  - criador encerra depois de fim + 1h → nega;
  - encerrar duas vezes → nega;
  - criador põe `endedAutomatically = true` → nega;
  - criador mexe em `ratedBy` → nega;
  - criador edita a descrição depois de encerrado → nega.
- [ ] O cabeçalho das regras perde a frase sobre `endedAt` com TODO, e o `TODO(tarefa 14)` de `events` sai, porque a Function do ticket 05 cuida do encerramento automático.
- [ ] Testes de widget: "Encerrar" só para o criador, a confirmação e a faixa para o participante.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [ ] Resultado das hipóteses 1 e 2 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: criador encerra o evento ao vivo`

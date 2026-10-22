# 09: Avaliar o evento e o Local Esportivo

Status: resolved

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 08 — Criador encerra o evento

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Gravar avaliação, App Check), §5.2, §6.3, §7 (ratings), §8.7, §8.9 (rota de avaliação) e §8.10 (Avaliação).

Hipóteses a conferir (§13):

- 4: `cloud_functions` resolve com Dart 3.13 e `firebase_core` 3.15.2, e o emulador funciona na web;
- 5: `increment` em mapa aninhado com merge soma em vez de sobrescrever;
- 8: a rota fora do shell abre com `push` e volta com `pop`;
- 10: evento legado sem `placeId` pula o passo do local.

**What to build:** Depois do fim, quem participou avalia.

- **Callable:** `submitEventRatings` não impõe App Check, e o motivo fica comentado no código. Ela valida tudo no servidor e grava numa transação as avaliações, os agregados em `ratingSummaries` e o `ratedBy` do evento. A coleção `ratings` fica 100% fechada ao cliente (D13).
- **Tela:** a avaliação abre em tela cheia, fora do shell.
  - O participante passa por Evento ("Como foi o evento?") e Local ("E o local?").
  - O criador passa só pelo Local, porque não avalia o próprio evento (D14).
  - Evento sem local pula esse passo.
- **Cada passo:** 5 estrelas grandes com rótulo, comentário travado até escolher a nota, motivo obrigatório abaixo de 3 e o aviso de que o comentário não é público. O envio termina na tela "Avaliação enviada!".
- **Entradas:** logo depois de "Encerrar evento" (criador), "Avaliar agora" na faixa da tela ao vivo (participante) e o CTA do detalhe encerrado.

O passo de participantes entra no ticket 10.

Este ticket entrega estas linhas da tabela de CTA do §8.4:

- **Encerrado, participante:** "Avaliar evento".
- **Encerrado, criador:** "Avaliar local e participantes". O texto já é o final, e o passo de participantes chega no 10.
- **Depois de avaliar:** "Você já avaliou", a partir de `ratedBy`.

## Acceptance criteria

- [x] **Parse estrito na callable:**
  - chaves exatas;
  - `eventId` com até 128 caracteres;
  - estrelas inteiras de 1 a 5;
  - comentário aparado, com até 500 caracteres;
  - motivo obrigatório abaixo de 3.

  Neste ticket, `participants` só aceita lista vazia.
- [x] **Matriz de validação do §6.3 contra o evento, dentro da transação:**
  - evento não existe → `not-found`;
  - evento não encerrado → `failed-precondition`;
  - quem chama não participa → `permission-denied`;
  - já avaliou → `already-exists`;
  - o criador mandou `event`, ou um não criador não mandou → `invalid-argument`;
  - `place` incoerente com o `placeId` → `invalid-argument`.
- [x] **Transação:**
  - todas as leituras vêm antes das escritas;
  - as `ratings` são criadas com id composto, e uma duplicidade falha;
  - os agregados usam incremento (soma, contagem e contagem por estrela);
  - o uid entra no `ratedBy`;
  - a resposta é `{ ratedTargets }`.
- [x] Testes com fakes: a matriz inteira, "criador avalia o local" e "evento legado sem local". O teste de região inclui a callable.
- [x] Regras: o bloco de `ratings` é substituído por "tudo negado", e o TODO sai. A suíte nova de `ratings` nega create, read, update e delete.
- [x] **App:**
  - dependência `cloud_functions` numa linha compatível;
  - emulador de Functions ligado no modo emulador;
  - feature de avaliações com domínio (rascunho, validação pura e envio);
  - dados: a callable, com os códigos de erro mapeados para exceções de domínio (já avaliou, ainda não terminou, só quem participou, sem conexão e genérico);
  - mock que registra o envio e marca `ratedBy` no store de eventos.
- [x] Widget de estrelas compartilhado, em modo de entrada, com alvo de toque de pelo menos 48px e semântica "N de 5 estrelas".
- [x] **Tela de avaliação:**
  - "X" pede confirmação ("Sair sem enviar?") quando há algo preenchido;
  - mostra "Passo i de n";
  - "Continuar" só fica ativo com o passo válido;
  - erros aparecem em SnackBar, com texto das strings;
  - `already-exists` mostra "Você já avaliou este evento." e fecha o fluxo.
- [x] A rota `/avaliacao/:eventId` fica na raiz, fora do shell. Ela abre com `push`, fecha com `pop` e entra no teste do `authRedirect`, sem redirecionar usuário completo.
- [x] Entradas ligadas: depois de encerrar, o criador cai na avaliação; "Avaliar agora" aparece na faixa da tela ao vivo; os CTAs do detalhe encerrado funcionam.
- [x] **Testes:**
  - validação pura;
  - o fluxo não avança sem estrelas;
  - o comentário fica travado até ter nota;
  - nota abaixo de 3 exige comentário;
  - o criador não tem o passo do evento.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] `npm run lint --prefix functions` e `npm test --prefix functions` verdes.
- [x] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [x] Resultado das hipóteses 4, 5, 8 e 10 anotado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Hipóteses (§13), conferidas em 21/10/2026:

- **4:** parcial. O `cloud_functions` resolveu na 5.6.2 com `firebase_core` 3.15.2 (Dart 3.13.5), e o app compila e testa. O `useFunctionsEmulator('localhost', 5001)` está ligado no modo emulador, mas só vai ser exercitado na web no E2E (ticket 14).
- **5:** confirmada no emulador. `set(..., { merge: true })` com `starCounts: { '5': increment(1) }` soma: duas notas 5 e uma nota 3 deram `starCounts {5: 2, 3: 1}`, `count` 3 e `sum` 13.
- **8:** confirmada por teste de rota (`test/core/routes/rating_route_test.dart`). A rota na raiz, aberta com `push` de dentro de uma aba, cobre a barra inferior, e o `pop` volta para a aba.
- **10:** confirmada. O evento legado sem `placeId` pula o passo do local (teste de widget), e a callable recusa nota de local para ele.

Notas:

- A callable já valida a lista de participantes inteira (uid repetido, quem não participou ou a própria pessoa → `invalid-argument`) e grava as notas `user`. O ticket 10 só precisa do passo no app.
- Até o ticket 10, o criador de um evento legado sem local, mas com outros participantes, vê "Avaliar local e participantes" no detalhe e cai em "Não há o que avaliar neste evento.". O passo de participantes resolve isso.
- A marcação de "Avaliado" na notificação fica para o ticket 11, como na quebra aprovada.
- "Voltar", na tela de sucesso, leva ao detalhe do evento (que mostra "Você já avaliou"). O "X" volta para onde a avaliação foi aberta.
- A suíte de regras foi para 157 casos (7 novos em `ratings.test.js`), e a das Functions para 65 testes.

Commit sugerido: `feat: avaliacao do evento e do local via cloud function`

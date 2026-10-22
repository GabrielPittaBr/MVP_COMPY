# 04: Eventos encerrados somem das listas e não aceitam mais participantes

Status: resolved

Blocked by: 03 — Status derivado do evento

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Encerrados nas listas, Entrar em evento), §7 (create e `isJoin`), §8.2 e §8.11 (fixtures datadas).

Hipóteses a conferir (§13): 1 (aritmética de tempo nas regras, inclusive documento legado sem `endsAt`).

**What to build:** Aplica a D17 nas listas. Nenhum evento encerrado aparece em "Todos os eventos", "Criados por mim", "Participando", nos "Eventos próximos" da Home ou na busca.

- As consultas ganham um limite inferior: `notBefore` = agora − (duração máxima + tolerância). Isso também resolve um problema de hoje: eventos passados empurram os atuais para fora do `limit`.
- O que passar desse limite e já estiver encerrado é removido no cliente, com o relógio.
- No servidor, a regra deixa de aceitar evento criado com campos de ciclo de vida e nega a entrada em evento encerrado, seja por `endedAt`, seja por tempo.

Nada muda no visual, então este ticket não espera o design.

## Acceptance criteria

- [x] Nenhum evento encerrado aparece nas cinco listas, no Firestore e no mock. Os testes usam relógio fixo.
- [x] Com filtro de dia, o limite inferior é o maior entre o início do dia e `notBefore`. Nenhum índice composto novo é criado.
- [x] "Todos os eventos" não fica com spinner infinito quando uma página inteira é filtrada: `loadMore` busca as próximas páginas, com um limite de voltas.
- [x] A busca filtra os encerrados só no cliente.
- [x] Regras:
  - create com `endedAt`, `endedAutomatically` ou `ratedBy` → nega;
  - join em evento com `endedAt` → nega;
  - join depois de fim + 1h → nega;
  - join durante o evento → permite;
  - documento legado sem `endsAt` usa início + 60 min.
- [x] As fixtures com data fixa no passado, no teste do repositório de eventos e na suíte de regras, passam a ser relativas a agora. O grupo que escreve no store singleton continua sem interferir nos outros testes.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [x] Resultado da hipótese 1 anotado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Hipótese 1 (§13), conferida em 21/10/2026 no emulador: `resource.data.get('endsAt', resource.data.dateTime + duration.value(60, 'm'))` e `plannedEnd() + duration.value(1, 'h')` funcionam. O documento legado sem `endsAt` aceita o join dentro de início + 60 min + 1h e nega depois disso. A suíte de regras foi de 132 para 140 casos.

Notas:

- O limite inferior com dia escolhido (o maior entre o início do dia e `notBefore`) fica no `EventsRemoteDataSource`. Ele não tem teste de unidade, porque o `QueryDocumentSnapshot` é `@sealed` e um fake dele geraria aviso no analyzer. O filtro de cliente (`withoutEnded`) é o mesmo nos dois caminhos e é testado pelo mock com relógio fixo.
- A Home e as seções filtram com o relógio na hora em que os dados chegam. Um evento que encerra com a tela parada só some na próxima emissão ou recarga; a reavaliação contínua com o `nowProvider` entra com o selo (ticket 06).
- Os contadores de testes do README ficam para o ticket 15.

Commit sugerido: `feat: listas escondem eventos encerrados e regra fecha o join depois do fim`

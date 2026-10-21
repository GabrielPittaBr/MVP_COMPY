# 04: Eventos encerrados somem das listas e não aceitam mais participantes

Status: open

Blocked by: 03 — Status derivado do evento

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Encerrados nas listas, Entrar em evento), §7 (create e `isJoin`), §8.2 e §8.11 (fixtures datadas).

Hipóteses a conferir (§13): 1 (aritmética de tempo nas regras, inclusive documento legado sem `endsAt`).

**What to build:** Aplica a D17 nas listas. Nenhum evento encerrado aparece em "Todos os eventos", "Criados por mim", "Participando", nos "Eventos próximos" da Home ou na busca.

- As consultas ganham um limite inferior: `notBefore` = agora − (duração máxima + tolerância). Isso também resolve um problema de hoje: eventos passados empurram os atuais para fora do `limit`.
- O que passar desse limite e já estiver encerrado é removido no cliente, com o relógio.
- No servidor, a regra deixa de aceitar evento criado com campos de ciclo de vida e nega a entrada em evento encerrado, seja por `endedAt`, seja por tempo.

Nada muda no visual, então este ticket não espera o design.

## Acceptance criteria

- [ ] Nenhum evento encerrado aparece nas cinco listas, no Firestore e no mock. Os testes usam relógio fixo.
- [ ] Com filtro de dia, o limite inferior é o maior entre o início do dia e `notBefore`. Nenhum índice composto novo é criado.
- [ ] "Todos os eventos" não fica com spinner infinito quando uma página inteira é filtrada: `loadMore` busca as próximas páginas, com um limite de voltas.
- [ ] A busca filtra os encerrados só no cliente.
- [ ] Regras:
  - create com `endedAt`, `endedAutomatically` ou `ratedBy` → nega;
  - join em evento com `endedAt` → nega;
  - join depois de fim + 1h → nega;
  - join durante o evento → permite;
  - documento legado sem `endsAt` usa início + 60 min.
- [ ] As fixtures com data fixa no passado, no teste do repositório de eventos e na suíte de regras, passam a ser relativas a agora. O grupo que escreve no store singleton continua sem interferir nos outros testes.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [ ] Resultado da hipótese 1 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: listas escondem eventos encerrados e regra fecha o join depois do fim`

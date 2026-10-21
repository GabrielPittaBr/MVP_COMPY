# 03: Status derivado do evento (agendado, acontecendo, encerrado)

Status: open

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Status), §5.1, §8.1 e §8.11 (mock).

**What to build:** O Evento Esportivo passa a saber o próprio status em qualquer instante. O status é derivado no cliente:

- **encerrado**, se tem `endedAt`;
- **agendado**, antes do início;
- **acontecendo**, até 1h depois do fim previsto (`kEventEndTolerance`);
- **encerrado** depois disso, mesmo antes de a Function gravar.

O app ganha um relógio injetável, para que telas e testes usem o mesmo "agora". O modelo lê os três campos de ciclo de vida (`endedAt`, `endedAutomatically` e `ratedBy`), mas nunca os grava. O mock fica coerente, para demonstrar as fases seguintes. O formulário de criação deixa de aceitar início no passado.

## Acceptance criteria

- [ ] `statusAt(agora)` está correto nas bordas: exatamente no início, exatamente no fim previsto, exatamente em fim + 1h e com `endedAt` gravado antes do início.
- [ ] O evento lê `endedAt`, `endedAutomatically` (padrão false) e `ratedBy` (padrão vazio). Os três entram na igualdade e no `copyWith`, e a serialização para o Firestore não grava nenhum deles.
- [ ] Existe um relógio injetável (`clockProvider`) e um "agora" que se atualiza a cada 30s (`nowProvider`). Os dois podem ser sobrescritos com valor fixo nos testes.
- [ ] A duração máxima do evento vira uma constante compartilhada, que o formulário também usa.
- [ ] O formulário de criação não deixa escolher início no passado (mostra mensagem e bloqueia o botão). Isso vale também para horário anterior a agora no dia de hoje.
- [ ] Mock:
  - criar evento gera id, e a rota de detalhe deixa de quebrar;
  - o usuário mock está entre os participantes do evento que ele cria;
  - as fixtures ganham um evento ao vivo (começou há 20 min, dura 1h, com o usuário mock participando);
  - as fixtures ganham um evento encerrado (terminou ontem, com `endedAt`, com o usuário mock participando, sem avaliação);
  - todas as datas são relativas a agora.
- [ ] Testes de unidade do status e do formulário.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: status derivado do evento (agendado, acontecendo, encerrado)`

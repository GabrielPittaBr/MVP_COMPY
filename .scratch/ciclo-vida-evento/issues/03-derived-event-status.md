# 03: Status derivado do evento (agendado, acontecendo, encerrado)

Status: resolved

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Status), §5.1, §8.1 e §8.11 (mock).

**What to build:** O Evento Esportivo passa a saber o próprio status em qualquer instante. O status é derivado no cliente:

- **encerrado**, se tem `endedAt`;
- **agendado**, antes do início;
- **acontecendo**, até 1h depois do fim previsto (`kEventEndTolerance`);
- **encerrado** depois disso, mesmo antes de a Function gravar.

O app ganha um relógio injetável, para que telas e testes usem o mesmo "agora". O modelo lê os três campos de ciclo de vida (`endedAt`, `endedAutomatically` e `ratedBy`), mas nunca os grava. O mock fica coerente, para demonstrar as fases seguintes. O formulário de criação deixa de aceitar início no passado.

## Acceptance criteria

- [x] `statusAt(agora)` está correto nas bordas: exatamente no início, exatamente no fim previsto, exatamente em fim + 1h e com `endedAt` gravado antes do início.
- [x] O evento lê `endedAt`, `endedAutomatically` (padrão false) e `ratedBy` (padrão vazio). Os três entram na igualdade e no `copyWith`, e a serialização para o Firestore não grava nenhum deles.
- [x] Existe um relógio injetável (`clockProvider`) e um "agora" que se atualiza a cada 30s (`nowProvider`). Os dois podem ser sobrescritos com valor fixo nos testes.
- [x] A duração máxima do evento vira uma constante compartilhada, que o formulário também usa.
- [x] O formulário de criação não deixa escolher início no passado (mostra mensagem e bloqueia o botão). Isso vale também para horário anterior a agora no dia de hoje.
- [x] Mock:
  - criar evento gera id, e a rota de detalhe deixa de quebrar;
  - o usuário mock está entre os participantes do evento que ele cria;
  - as fixtures ganham um evento ao vivo (começou há 20 min, dura 1h, com o usuário mock participando);
  - as fixtures ganham um evento encerrado (terminou ontem, com `endedAt`, com o usuário mock participando, sem avaliação);
  - todas as datas são relativas a agora.
- [x] Testes de unidade do status e do formulário.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Notas:

- O minuto atual ainda conta como início válido: o horário não tem segundos, e começar agora é legítimo. Se o relógio passar do horário escolhido com o formulário aberto, o aviso aparece e o envio é barrado de novo no `_submit`.
- O `evt_001` do mock tinha 10 participantes, 14 vagas e 5 restantes; as restantes viraram 4, para a conta fechar como nos outros.

Commit sugerido: `feat: status derivado do evento (agendado, acontecendo, encerrado)`

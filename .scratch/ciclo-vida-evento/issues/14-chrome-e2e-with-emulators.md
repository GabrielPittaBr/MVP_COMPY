# 14: E2E no Chrome com emuladores

Status: open

Blocked by: 02 a 13 — todos os tickets de código

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §11.2 e §11.3.

Hipóteses a conferir na prática (§13): 6 (o gatilho dispara no emulador com escrita pela REST) e 8 (`push` e `pop` da avaliação no navegador).

**What to build:** O roteiro do §11.3 executado de ponta a ponta no Chrome, contra os emuladores de Auth, Firestore e Functions. Nunca contra o `compy-tcc`.

- **Preparação:** três contas (o criador, um participante e alguém de fora do evento) e a Quadra de Teste semeada no emulador.
- **O que o roteiro cobre:**
  - o evento ao vivo e a DM;
  - o encerramento manual, com as duas avaliações;
  - a notificação e o "Avaliado";
  - o sumiço do evento das listas;
  - as médias;
  - o encerramento automático simulado, com o diálogo único;
  - as regressões.
- **Bugs:** os pequenos são corrigidos aqui, com teste. Os grandes viram ticket novo.

## Acceptance criteria

- [ ] Os passos 1 a 9 do §11.3 foram conferidos, com o resultado de cada um registrado neste ticket.
- [ ] Nenhum alerta do navegador foi disparado. O trabalho foi feito em abas próprias, criadas a partir do contexto do navegador.
- [ ] As correções vieram com teste automatizado, e as suítes ficaram verdes de novo.

## Verification

- [ ] Emuladores e app parados no fim.
- [ ] Todas as suítes verdes depois das correções: `flutter test`, `dart analyze`, Functions (lint e test) e regras.
- [ ] Resultado das hipóteses 6 e 8 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `fix: ...` para cada correção, ou `docs: registra o e2e da tarefa 14` se nada mudar no código.

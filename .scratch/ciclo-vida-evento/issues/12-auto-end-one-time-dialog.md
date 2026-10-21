# 12: Aviso único ao criador de encerramento automático

Status: open

Blocked by: 11 — Central de notificações com o convite para avaliar

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Aviso de encerramento automático), §8.6 (Diálogo único) e §8.10 (Diálogo).

Hipóteses a conferir (§13): 7 (o scaffold do shell virar `ConsumerStatefulWidget` não quebra a troca de abas nem a preservação de estado delas).

**What to build:** Implementa a D5, usando a notificação como mecanismo único. O app abre e as notificações são lidas pela primeira vez. Se houver uma de evento encerrado automaticamente, do próprio criador e ainda não lida, aparece o diálogo:

- título "Seu evento foi encerrado automaticamente";
- corpo "O {título} passou 1h do horário previsto e encerramos por você. Que tal avaliar o local e quem jogou?";
- ações "Agora não" e "Avaliar".

Ao mostrar o diálogo, a notificação já é marcada como lida, então o aviso aparece uma única vez. "Avaliar" abre a avaliação. Notificações que chegam depois, com o app aberto, só mudam o badge.

## Acceptance criteria

- [ ] O diálogo só aparece na primeira emissão depois de abrir o app, e só para a primeira notificação encontrada. Emissões seguintes não abrem diálogo.
- [ ] Mostrar o diálogo grava `readAt`, e reabrir o app não mostra de novo.
- [ ] "Avaliar" abre a avaliação; "Agora não" só fecha.
- [ ] A troca de abas e o estado delas continuam como antes.
- [ ] Testes de widget:
  - o diálogo aparece uma vez;
  - não aparece para participante nem quando o encerramento foi manual;
  - não reaparece com uma emissão nova.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] Resultado da hipótese 7 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: aviso unico ao criador de evento encerrado automaticamente`

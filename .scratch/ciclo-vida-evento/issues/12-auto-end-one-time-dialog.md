# 12: Aviso único ao criador de encerramento automático

Status: resolved

Blocked by: 11 — Central de notificações com o convite para avaliar

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Aviso de encerramento automático), §8.6 (Diálogo único) e §8.10 (Diálogo).

Hipóteses a conferir (§13): 7 (o scaffold do shell virar `ConsumerStatefulWidget` não quebra a troca de abas nem a preservação de estado delas).

**What to build:** Implementa a D5, usando a notificação como mecanismo único. O app abre e as notificações são lidas pela primeira vez. Se houver uma de evento encerrado automaticamente, do próprio criador e ainda não lida, aparece o diálogo:

- título "Seu evento foi encerrado automaticamente";
- corpo "O {título} passou 1h do horário previsto e encerramos por você. Que tal avaliar o local e quem jogou?";
- ações "Agora não" e "Avaliar".

Ao mostrar o diálogo, a notificação já é marcada como lida, então o aviso aparece uma única vez. "Avaliar" abre a avaliação. Notificações que chegam depois, com o app aberto, só mudam o badge.

## Acceptance criteria

- [x] O diálogo só aparece na primeira emissão depois de abrir o app, e só para a primeira notificação encontrada. Emissões seguintes não abrem diálogo.
- [x] Mostrar o diálogo grava `readAt`, e reabrir o app não mostra de novo.
- [x] "Avaliar" abre a avaliação; "Agora não" só fecha.
- [x] A troca de abas e o estado delas continuam como antes.
- [x] Testes de widget:
  - o diálogo aparece uma vez;
  - não aparece para participante nem quando o encerramento foi manual;
  - não reaparece com uma emissão nova.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] Resultado da hipótese 7 anotado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Hipótese 7 (§13), conferida em 21/10/2026: confirmada, com uma mudança de desenho. Em vez de transformar o `_ScaffoldWithNavBar` em `ConsumerStatefulWidget`, ele continua `StatelessWidget` e envolve o scaffold num `AutoEndNotice` (`lib/features/notifications/presentation/widgets/auto_end_notice.dart`), que concentra o estado do aviso e pode ser testado sozinho. Um teste com `StatefulShellRoute` confere que trocar de aba e voltar preserva o estado da aba.

Notas:

- A primeira emissão é ouvida com `ref.listenManual(..., fireImmediately: true)` no `initState`, para pegar inclusive o valor que já estiver em cache. Depois dela, a flag `_checked` ignora as próximas.
- A notificação é marcada como lida antes de o diálogo abrir, como pede o plano. Se essa gravação falhar, o aviso reaparece na próxima abertura, o que é melhor que sumir.
- O corpo do diálogo começa pelo título do evento, sem o "O" inicial (decisão do ticket 01).

Commit sugerido: `feat: aviso unico ao criador de evento encerrado automaticamente`

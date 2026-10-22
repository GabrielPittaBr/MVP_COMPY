# 15: Fechamento: documentação, merge e deploy

Status: resolved

Blocked by: 14 — E2E no Chrome com emuladores

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §2 (D14 a D17), §3 (conflito com o ticket 17 do admin), §12, §14 (riscos para a ADR) e §15.

**What to build:** A tarefa 14 fica registrada e publicada.

- **Roadmap:** fecha a tarefa e ganha as decisões D14 a D17.
- **ADR 0002:** registra o ciclo de vida e as avaliações com Cloud Functions. Reabre explicitamente a decisão do ticket 17 do painel admin, porque agora a avaliação de Local Esportivo é real, com a média fora do documento do local. Registra também os riscos aceitos: `ratedBy` público e avaliações de conta excluída mantidas.
- **Glossário:** ganha os termos novos.
- **READMEs e runbook:** atualizam as contagens de testes e o deploy.
- **Merge e deploy:** depois da documentação, o merge local na `develop` e o deploy no `compy-tcc` de índices (se mudaram), Functions e regras, nessa ordem, com conferência. O usuário autorizou o deploy no §0 do plano; mesmo assim, avise antes de publicar. O push fica com o usuário.

## Acceptance criteria

- [x] O roadmap mostra a tarefa 14 fechada e as decisões D14 a D17.
- [x] A ADR 0002 deixa explícito o conflito com o ticket 17 do admin e traz os riscos do §14.
- [x] O `CONTEXT.md` tem os termos novos (por exemplo, encerramento, avaliação e notificação), sem os sinônimos que o glossário evita.
- [x] As contagens de testes estão atualizadas nos READMEs (o da raiz e o da suíte de regras).
- [x] O runbook de deploy traz as Functions novas, o rollback e o motivo do `enforceAppCheck: false`.
- [x] Merge `--no-ff` na `develop`, com a mensagem `merge: feature/ciclo-vida-evento em develop`, e sem push.
- [x] Deploy só com tudo verde:
  - Functions antes das regras;
  - `functions:list` mostra as três novas em `southamerica-east1`;
  - o log da agendada não tem erro.

  Se o primeiro deploy do gatilho gen2 falhar por permissão do Eventarc, espere e repita.
- [x] O resultado do deploy está anotado no caderno e no runbook.
- [x] Todos os critérios finais do §15 estão marcados.

## Verification

- [x] Todas as suítes verdes na `develop` depois do merge, antes do deploy.
- [x] `firebase functions:list --project compy-tcc` conferido e registrado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

## Resultado (22/10/2026)

- Merge `bc4aec5` na `develop`, sem push.
- Suítes na `develop` antes do deploy: Flutter 343/343, `dart analyze` com os 10 avisos da linha de base, Functions com lint limpo e 81/81, regras 167/167.
- Índices sem mudança. Functions primeiro: `onEventEnded` falhou na primeira vez pela permissão do Eventarc e subiu na repetição, quatro minutos depois. Regras depois.
- `firebase functions:list --project compy-tcc`: `autoEndOverdueEvents` (scheduled), `onEventEnded` (`google.cloud.firestore.document.v1.updated`) e `submitEventRatings` (callable), além das três do painel, todas em v2, `southamerica-east1`, `nodejs22`.
- Log da agendada: primeira execução às 20:27 UTC, sem erro.
- Fica com o usuário: o push da `develop` e a geração e distribuição do APK novo.

Commit sugerido: `docs: fecha a tarefa 14 no roadmap, adr 0002 e readme`; depois do deploy, `docs: registra o deploy da tarefa 14`.

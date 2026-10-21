# 05: Encerramento automático de eventos esquecidos

Status: resolved

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Encerramento automático, Codebase das Functions), §6.1 e §6.4.

**What to build:** A Function agendada `autoEndOverdueEvents` roda a cada 10 min, no fuso de São Paulo. Ela encerra os eventos que passaram 1h do fim previsto sem que ninguém os encerrasse: grava `endedAt = endsAt + 1h` e `endedAutomatically = true`, numa transação que não sobrescreve um encerramento já feito. A tolerância é a mesma do app. A Function fica no codebase `administrative`, com a região explícita nas próprias opções.

O emulador de Functions entra na configuração, para o E2E. Ele não dispara agendamentos, então a agenda fica coberta pelos testes.

## Acceptance criteria

- [x] Só eventos vencidos e abertos são encerrados. Evento que já tem `endedAt` é ignorado.
- [x] O valor gravado é `endsAt + 1h`, com `endedAutomatically = true`.
- [x] Uma corrida simulada, em que a transação encontra o evento já encerrado, não conta como encerramento.
- [x] A janela inclui a borda exata de agora − 1h e olha até 2 dias para trás. Eventos legados sem `endsAt` ficam de fora.
- [x] A consulta não depende de `endedAt == null`, porque o campo fica ausente nos eventos abertos.
- [x] A Function é exportada no índice das Functions, e o teste de região confere `southamerica-east1`.
- [x] O emulador de Functions está configurado na porta 5001.

## Verification

- [x] `npm run lint --prefix functions` verde.
- [x] `npm test --prefix functions` verde (build + `node --test`).
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Notas:

- A suíte das Functions foi de 21 para 30 testes: 8 do encerramento automático e 1 que confere região, agenda e fuso no `__endpoint`.
- A consulta lê até 500 eventos por execução, do `endsAt` mais antigo para o mais novo, como no plano. Os já encerrados continuam na janela de 2 dias e ocupam lugar no lote. Só faria diferença com mais de 500 eventos terminando em 2 dias, longe do volume de Taquara.
- O emulador de Functions entrou na porta 5001 e ainda não foi subido. Ele é exercitado no E2E (ticket 14).

Commit sugerido: `feat: function agendada encerra eventos esquecidos`

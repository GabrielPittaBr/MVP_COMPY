# 05: Encerramento automático de eventos esquecidos

Status: open

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Encerramento automático, Codebase das Functions), §6.1 e §6.4.

**What to build:** A Function agendada `autoEndOverdueEvents` roda a cada 10 min, no fuso de São Paulo. Ela encerra os eventos que passaram 1h do fim previsto sem que ninguém os encerrasse: grava `endedAt = endsAt + 1h` e `endedAutomatically = true`, numa transação que não sobrescreve um encerramento já feito. A tolerância é a mesma do app. A Function fica no codebase `administrative`, com a região explícita nas próprias opções.

O emulador de Functions entra na configuração, para o E2E. Ele não dispara agendamentos, então a agenda fica coberta pelos testes.

## Acceptance criteria

- [ ] Só eventos vencidos e abertos são encerrados. Evento que já tem `endedAt` é ignorado.
- [ ] O valor gravado é `endsAt + 1h`, com `endedAutomatically = true`.
- [ ] Uma corrida simulada, em que a transação encontra o evento já encerrado, não conta como encerramento.
- [ ] A janela inclui a borda exata de agora − 1h e olha até 2 dias para trás. Eventos legados sem `endsAt` ficam de fora.
- [ ] A consulta não depende de `endedAt == null`, porque o campo fica ausente nos eventos abertos.
- [ ] A Function é exportada no índice das Functions, e o teste de região confere `southamerica-east1`.
- [ ] O emulador de Functions está configurado na porta 5001.

## Verification

- [ ] `npm run lint --prefix functions` verde.
- [ ] `npm test --prefix functions` verde (build + `node --test`).
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: function agendada encerra eventos esquecidos`

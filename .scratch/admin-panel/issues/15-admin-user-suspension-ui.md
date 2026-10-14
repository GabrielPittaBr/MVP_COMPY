# 15: Entregar controles de Suspensão Administrativa no painel

Status: resolved

Blocked by: 13 — Entregar descoberta e detalhe administrativo de Usuário; 14 — Implementar Callable idempotente de Suspensão Administrativa

Spec: §§ 15, 19, 21 e Testing Decisions / Painel Flutter Web.

**What to build:** O detalhe de Usuário oferece suspensão e reativação como ações sensíveis isoladas, usando a Callable idempotente e comunicando corretamente os limites da revogação de token.

## Acceptance criteria

- [x] Suspender e reativar ficam separados de dados de perfil e não aparecem para Perfil sem Conta de Usuário.
- [x] Ações exigem motivo válido e confirmação final com UID, ação e aviso adequado.
- [x] UI não apresenta a suspensão como bloqueio instantâneo de todo ID token já emitido.
- [x] Cada envio gera UUID v4 novo; retry incerto preserva o mesmo ID e os parâmetros até obter resultado terminal.
- [x] Controles ficam desabilitados durante a operação e nunca mudam estado otimisticamente.
- [x] Sucesso usa snackbar; falha aparece próxima da ação; dados e motivo permanecem recuperáveis após falha.
- [x] Tentativas sobre Administrador, própria conta administrativa ou estado já desejado recebem mensagem segura; estado Auth é atualizado quando a consulta confirma mudança externa.
- [x] Testes cobrem confirmação, validação, loading, sucesso, erro, retry idempotente e acessibilidade.

## Verification

- [x] `flutter analyze --no-pub` no painel — exit code 0.
- [x] `flutter test --no-pub` no painel — 51 testes aprovados, exit code 0.
- [x] `flutter build web --no-pub` — exit code 0.
- [x] Functions `typecheck`, `lint` e `npm test` — todos com exit code 0; 19 testes aprovados.
- [x] `git diff --check` — exit code 0.

## Implementação e evidência

- O detalhe usa a Callable `setUserSuspension`, envia somente `uid`, ação, motivo normalizado e UUID v4, e valida o retorno mínimo antes de atualizar o estado exibido.
- Ações são indisponíveis quando não há conta Auth; um perfil Firestore sem Auth permanece sem controles, enquanto uma conta Auth sem perfil continua administrável conforme a spec.
- Erros de permissão, autorização/estado inválido e conta ausente são sanitizados na interface. Erros de resultado incerto preservam o mesmo `operationId` e bloqueiam edição do motivo até a reconciliação.
- A Callable agora inclui apenas `operationStatus: pending|failed` nos detalhes sanitizados do erro, permitindo à UI distinguir retries reconciliáveis de operações terminalmente falhas sem expor dados internos.
- A validação final foi feita com fake da Callable; não houve alteração de Rules, uso de Emulator, deploy ou chamada a Functions em produção.

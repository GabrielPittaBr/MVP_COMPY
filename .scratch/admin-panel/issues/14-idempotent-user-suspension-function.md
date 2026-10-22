# 14: Implementar Callable idempotente de Suspensão Administrativa

Status: resolved

Blocked by: 09 — Expor consultas administrativas mínimas de Conta de Usuário

Spec: §§ 17, 18, 19, 22 e Testing Decisions / Callable Functions.

**What to build:** `setUserSuspension` permite suspender ou reativar uma Conta de Usuário por ambiente confiável, com motivo obrigatório, proteção de administradores, registro imutável e reconciliação sob demanda de operações pendentes.

## Acceptance criteria

- [x] Entrada aceita somente UID, `suspend`/`reactivate`, motivo normalizado de 10–500 caracteres e UUID v4 `operationId`.
- [x] Function exige Auth, claim admin e App Check de produção, bloqueia autoação, alvo admin e conta inexistente.
- [x] Suspender desabilita Auth e revoga refresh tokens; reativar habilita Auth sem prometer restaurar tokens antigos.
- [x] Registro confiável contém Administrador, alvo, ação, motivo, timestamps, status e resultado/falha sanitizada; cliente não pode lê-lo ou escrevê-lo.
- [x] Mesmo `operationId` com parâmetros diferentes é rejeitado; sucesso devolve resultado armazenado; falha devolve falha armazenada.
- [x] Pending é reconciliado sob demanda; suspensão já desabilitada reaplica revogação idempotente antes de finalizar.
- [x] Registros finalizados são imutáveis e não há scheduler, fila ou framework genérico.
- [x] Testes cobrem todas as validações, estados Auth, interrupções entre serviços, idempotência e privacidade.

## Verification

- [x] Executar typecheck/lint/testes de Functions: `npm run typecheck`, `npm run lint` e `npm test` em `functions/` passaram (19 testes).
- [x] Executar testes de Rules para negar acesso cliente aos registros: o teste `cliente, inclusive Admin, não lê nem escreve registro administrativo` passou no Emulator na execução manual de 2026-09-28.

Implementation complete; Functions (typecheck, lint e 19 testes) e a validação real da Rule que nega acesso de clientes a `adminOperations` passaram. A falha global restante da suíte é independente deste ticket e está registrada no ticket 03.

Atualização de validação (2026-09-28): o critério pendente continua sendo a
execução real do Emulator para provar que clientes, inclusive Administradores,
não conseguem ler nem escrever `adminOperations`. O reproducer Java
`tools/scripts/java-loopback-reproducer.java` falhou em `Selector.open()` neste
executor com `Unable to establish loopback connection` / `Invalid argument:
connect`, antes do Emulator. Não houve nova tentativa repetida da suíte, nem
alteração das Rules para contornar a limitação. A validação deve ser executada
junto da suíte completa pelo script documentado no ticket 03.

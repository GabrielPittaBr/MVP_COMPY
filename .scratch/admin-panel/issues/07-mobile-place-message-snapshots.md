# 07: Compartilhar Mensagem de Local com snapshot e fallback histórico

Status: resolved

Blocked by: 03 — Introduzir contrato de Local Esportivo, Rules transitórias e migração; 04 — Fornecer repository Firestore de Local Esportivo ao mobile

Spec: §§ 12, 13, 21 e Testing Decisions / Firestore Rules e Mobile.

**What to build:** O chat passa a compartilhar somente Local Esportivo ativo atual, com snapshot mínimo de nome, imagem e modalidade principal; cards preferem dados atuais, preservam histórico e mantêm fallback para mensagens legadas.

## Acceptance criteria

- [x] Nova Mensagem de Local contém `placeId` e snapshot mínimo completo; mensagens de texto comum mantêm o formato atual.
- [x] Compartilhamento valida local ativo online antes de gravar; sem conexão não enfileira e preserva a intenção para retry.
- [x] Rules transitórias validam associação à conversa, remetente, local ativo e snapshot no commit sem quebrar mensagens legadas.
- [x] Card usa documento atual quando disponível, indica local inativo e impede novos usos nesse estado.
- [x] Falha de resolução usa snapshot; mensagem legada somente com ID sem resolução usa fallback visual genérico.
- [x] Mensagens existentes permanecem imutáveis.
- [x] Testes cobrem novo mapper, legado, fallback, inativo, offline e Rules de mensagem.

## Verification

- [x] `flutter analyze --no-pub lib/features/chat test/features/chat` — exit code 0.
- [x] `flutter test --no-pub test/features/chat` — 35 testes passaram, exit code 0.
- [x] `flutter test --no-pub` — 202 testes passaram, exit code 0.
- [x] `node --check tools/firestore-rules-tests/conversations.test.js` — exit code 0.
- [x] Suíte completa de Firestore Rules no Emulator — execução manual externa: 123 testes, 123 passaram, 0 falharam/cancelados, exit code 0.

### Evidência da validação das Rules

Validação manual completa fora do Codex: Java 21; Firestore Emulator iniciado e encerrado com sucesso; 17 suítes; 123 testes aprovados, nenhum falhou, foi cancelado, ignorado ou marcado como TODO; exit code 0 (`Script exited successfully (code 0)`).

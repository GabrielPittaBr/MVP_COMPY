# 09: Expor consultas administrativas mínimas de Conta de Usuário

Status: resolved

Blocked by: 02 — Preparar tooling confiável Firebase e fundação de Functions

Spec: §§ 16, 17, 22 e Testing Decisions / Callable Functions.

**What to build:** As Callables `getAdminUserAuthDetails` e `getAdminUsersAuthStatus` fornecem somente metadados Auth aprovados para Administradores, sem abrir acesso direto a dados privados ou criar API administrativa genérica.

## Acceptance criteria

- [x] Ambas as Callables são gen2, TypeScript, `southamerica-east1` e exigem Auth, claim `admin === true` e App Check quando enforcement de produção estiver ativo.
- [x] Detalhe aceita exatamente UID ou e-mail, valida whitelist e retorna somente UID, e-mail, verificação, providers, criação, último login e `disabled`.
- [x] Consulta em lote aceita 1–20 UIDs sem duplicatas e retorna somente UID/`disabled`, omitindo contas ausentes.
- [x] Erros de autenticação, autorização, payload e conta inexistente usam códigos seguros e não vazam detalhes internos.
- [x] Nenhuma Function lê ou retorna documento privado de perfil.
- [x] Testes cobrem todos os papéis, entradas inválidas, conta sem e-mail, providers múltiplos, lote e minimização de dados.

## Verification

- [x] Executar typecheck/lint/testes das Functions e integração com emuladores/fakes adequados.

## Answer

Implementadas as Callables gen2 `getAdminUserAuthDetails` e
`getAdminUsersAuthStatus` na região centralizada `southamerica-east1`, com
`enforceAppCheck: true`. Ambas exigem Auth e a claim booleana `admin === true`
no servidor. Os handlers aceitam gateways de Auth injetáveis e não leem
Firestore, perfis públicos ou documentos privados.

O detalhe tem whitelist exata para UID ou e-mail, normaliza e-mail e reduz a
resposta ao contrato aprovado. A consulta em lote aceita de 1 a 20 UIDs
distintos, preserva a ordem dos encontrados e omite ausentes. Erros do Admin
SDK são reduzidos a códigos Callable seguros.

Validação: `npm run typecheck --prefix functions`, `npm run lint --prefix
functions` e `npm test --prefix functions` aprovados (10 testes). Os testes
usam fakes injetáveis para cobrir Auth, claim, payload, conta ausente,
minimização de dados e lote; o comportamento de App Check é configurado pela
opção nativa da Callable e terá smoke test hospedado antes do deploy.

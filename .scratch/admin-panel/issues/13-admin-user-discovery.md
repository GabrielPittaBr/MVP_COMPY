# 13: Entregar descoberta e detalhe administrativo de Usuário

Status: resolved

Blocked by: 08 — Normalizar Perfis de Usuário para pesquisa administrativa; 09 — Expor consultas administrativas mínimas de Conta de Usuário; 10 — Proteger acesso e entregar shell do Painel Administrativo

Spec: §§ 14, 15, 16, 21 e Testing Decisions / Painel Flutter Web.

**What to build:** O painel permite listar e pesquisar Perfis de Usuário por seletor explícito, consultar detalhes Auth mínimos e apresentar corretamente contas sem perfil, perfis sem conta e estado indisponível. Não inclui ainda mutação de conta.

## Acceptance criteria

- [x] Seletor explícito oferece Nome, Handle, UID e E-mail sem inferência ou consultas paralelas ocultas.
- [x] Nome e Handle usam prefixo paginado de 20 perfis; UID e E-mail usam consulta Auth exata.
- [x] Lista exibe avatar, nome, handle, modalidades favoritas e estado obtido por uma chamada em lote por página.
- [x] Detalhe exibe somente dados públicos aprovados e metadados Auth mínimos.
- [x] Conta Auth sem perfil mostra `Perfil não encontrado`; perfil sem Auth mostra `Conta não encontrada` e não oferece ação futura.
- [x] Falha do lote mostra `Estado indisponível`, sem supor estado ativo.
- [x] Estados de loading, cache/offline, vazio, erro, paginação, retry, teclado e foco são tratados.
- [x] Testes cobrem todos os tipos de busca, paginação, resultados ausentes, falha do lote e privacidade do payload.

## Verification

- [x] `flutter analyze --no-pub` — sem issues, exit code 0.
- [x] `flutter test --no-pub test/admin_users_test.dart` — 9 testes passaram, exit code 0.
- [x] `flutter test --no-pub` — 30 testes passaram, exit code 0.
- [x] `flutter build web --no-pub` — build concluído, exit code 0.
- [x] Fakes dos dois contratos Callable verificam os endpoints e payloads exatos; os handlers Functions existentes não foram alterados.
- [x] `git diff --check` — exit code 0.

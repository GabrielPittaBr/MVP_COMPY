# 12: Entregar ciclo seguro de criação, edição e status de Local Esportivo

Status: resolved

Blocked by: 03 — Introduzir contrato de Local Esportivo, Rules transitórias e migração; 11 — Entregar Dashboard e descoberta administrativa de Locais Esportivos

Spec: §§ 5, 6, 7, 21 e Testing Decisions / Painel Flutter Web.

**What to build:** O Administrador cria Local Esportivo inativo, edita conteúdo completo, visualiza mapa/imagem, ativa, desativa e reativa com confirmação e proteção contra conflito de `updatedAt`.

## Acceptance criteria

- [x] Formulário valida todos os campos do schema, modalidades, endereço, CEP, UF, coordenadas e URL HTTPS antes de enviar.
- [x] Mapa permite selecionar ponto e editar latitude/longitude; coordenada distante de Taquara produz aviso não bloqueante.
- [x] Preview de imagem, validação inline, resumo de erros, preservação de valores e confirmação de saída funcionam.
- [x] Criação gera somente local completo `inactive` e informa sucesso apenas após confirmação de servidor.
- [x] Edição usa transação e versão `updatedAt`; conflito não sobrescreve nem apaga o formulário e oferece recarregar.
- [x] Ativação/desativação/reativação são ações separadas; desativação explica impacto e pede confirmação.
- [x] Escritas não são suportadas offline, não entram em estado otimista e não possuem fila própria.
- [x] Nenhuma ação oferece exclusão física.
- [x] Testes cobrem validações, transação, conflito, estado offline, confirmações, preview e acessibilidade.

## Verification

- [x] `flutter analyze --no-pub` — exit code 0.
- [x] `flutter test --no-pub` — 41 testes passaram, exit code 0; suíte focada do ciclo de Locais — 11 passaram, exit code 0.
- [x] `flutter build web --no-pub` — compilação concluída, exit code 0.
- [x] `git diff --check` — exit code 0.
- [x] Regras usadas pelas mutações não foram alteradas neste ticket. A validação manual externa existente e registrada no ticket 11 cobriu 131/131 testes em 17 suítes (exit code 0), incluindo criação completa inicialmente inativa, rejeição de criação ativa/usuário comum, schema, update com `updatedAt` de servidor, imutabilidade de `createdAt` e delete negado. A validação foi reutilizada porque o ticket 12 não alterou Rules; não foi apresentada como uma nova execução do Emulator.

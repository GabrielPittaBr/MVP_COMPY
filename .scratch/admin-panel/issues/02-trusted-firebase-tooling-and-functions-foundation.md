# 02: Preparar tooling confiável Firebase e fundação de Functions

Status: resolved

Blocked by: None (can start immediately)

Spec: §§ 2, 4, 17, 18, 23 e Testing Decisions / Scripts e implantação.

**What to build:** A fundação TypeScript confiável para Firebase Admin SDK e Functions de segunda geração em `southamerica-east1`, incluindo o script local idempotente de bootstrap do primeiro Administrador. O resultado verificável é um pacote testável que nunca versiona credenciais e pode validar uma Conta de Usuário antes de atribuir `admin: true`.

## Acceptance criteria

- [x] Projeto TypeScript de Functions é configurado para gen2 e região `southamerica-east1`, sem expor uma Function administrativa genérica.
- [x] Tooling de Admin SDK usa credencial externa/ADC e falha com mensagem segura quando ela não está disponível.
- [x] Script de bootstrap recebe um UID, possui dry-run, valida existência, conta habilitada, e-mail verificado e provider password.
- [x] Bootstrap preserva claims existentes, concede somente `admin: true` e é no-op idempotente quando a claim já existe.
- [x] O script não altera senha, e-mail, providers ou verificação e não revela segredos na saída.
- [x] Há testes para todos os caminhos do bootstrap e para a inicialização confiável.
- [x] `.gitignore` protege service accounts, tokens de debug e `.env` secretos relacionados à nova infraestrutura.

## Verification

- [x] Executar typecheck/lint/testes TypeScript locais.
- [x] Executar bootstrap em dry-run com gateway/fake de Admin SDK.
- [x] Confirmar que nenhum segredo foi criado ou rastreado pelo Git.

## Answer

Criados o codebase `functions/` TypeScript para Functions gen2, com região
centralizada em `southamerica-east1`, e o pacote separado
`tools/firebase-admin/` para comandos privilegiados locais. Não há Function
administrativa genérica ou deploy configurado nesta etapa.

O comando `bootstrap-admin` aceita exatamente `--uid <UID>` e `--dry-run`.
Ele usa somente ADC/`GOOGLE_APPLICATION_CREDENTIALS` externo, valida conta
habilitada, e-mail presente/verificado e provider `password`, preserva claims
existentes e é no-op quando `admin: true` já existe. Nenhuma credencial foi
criada ou usada nesta validação.

Validação: typecheck e lint aprovados nos dois pacotes; 1 teste das Functions
e 15 testes do tooling aprovados; JSON do Firebase validado; busca por padrões
de segredo no novo código sem resultados e `git diff --check` aprovado.

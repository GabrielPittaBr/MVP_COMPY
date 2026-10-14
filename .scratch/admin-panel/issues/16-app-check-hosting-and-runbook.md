# 16: Preparar App Check, Firebase Hosting e runbook de implantação

Status: resolved

Blocked by: 01 — Criar a fundação Flutter Web do Painel Administrativo; 09 — Expor consultas administrativas mínimas de Conta de Usuário; 10 — Proteger acesso e entregar shell do Painel Administrativo

Spec: §§ 22, 23, 24, 25 e Further Notes / Riscos e dependências externas.

**What to build:** Configuração versionada e documentação operacional para o painel usar App Check Web, Firebase Hosting em target dedicado e Functions gen2, sem executar configurações remotas que dependem do responsável pelo projeto.

## Acceptance criteria

- [x] Painel ativa App Check Web com reCAPTCHA v3 por configuração pública de build, sem token de debug ou segredo no Git.
- [x] Ambiente local prevê debug provider/token por variável externa e falha de forma clara quando ausente.
- [x] Configuração Firebase prevê target Hosting `admin`, artefato Web, URL sem `#` e rewrite SPA para todas as rotas.
- [x] Functions ficam preparadas para `enforceAppCheck: true` em produção após validação do domínio hospedado.
- [x] Runbook descreve exatamente pré-requisitos Blaze, orçamento, alertas, CLI autenticada, criação/associação do site, domínio autorizado, reCAPTCHA e token debug.
- [x] Runbook separa passos locais seguros de passos remotos manuais e inclui rollback de Hosting, Rules, Functions e contract.
- [x] Não ativa enforcement global do Firestore nem replay protection beta.
- [x] Testes/análise locais verificam configuração e build sem exigir Console ou deploy.

## Verification

- [x] Executar análise/testes/build Web locais: `flutter analyze --no-pub` passou; `flutter test --no-pub` passou (10 testes); `flutter build web --no-pub` passou com exit code 0.
- [x] Validar sintaxe de configuração Firebase e scripts PowerShell; nenhum segredo ou token foi adicionado ao Git.

O FlutterFire 0.4.x requer `firebase_core` 4.x, incompatível com os demais plugins Firebase 3.x usados pelo painel. A implementação mantém o FlutterFire 0.3.x já resolvido e ativa o token debug pelo mecanismo oficial do Firebase Web antes da ativação de App Check. Nenhuma migração ampla de Firebase foi feita.

Configuração local, Hosting e runbook estão prontos. Ainda são necessárias ações manuais no projeto Firebase antes do deploy: Blaze, orçamento/alertas, autenticação CLI, criação/associação do site Hosting, configuração reCAPTCHA v3/App Check, autorização do token de debug e validação do domínio do Hosting. Nenhum deploy ou configuração remota foi executado.

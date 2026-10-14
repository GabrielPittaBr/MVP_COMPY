# 01: Criar a fundação Flutter Web do Painel Administrativo

Status: resolved

Blocked by: None (can start immediately)

Spec: §§ 2, 3, 21 e Testing Decisions / Painel Flutter Web.

**What to build:** Uma aplicação Flutter Web independente para o Painel Administrativo, pronta para compilar, analisar e testar sem importar código do mobile. Ela estabelece somente o esqueleto feature-first, tema Material 3, infraestrutura de Firebase, configuração de testes e uma tela de bootstrap neutra; ainda não concede acesso administrativo nem consulta dados.

## Acceptance criteria

- [x] A aplicação tem raiz `admin/`, configuração Flutter própria e build Web funcional.
- [x] Dependências incluem somente o necessário para Firebase Web, Auth, Firestore, Functions, App Check, Riverpod, GoRouter e mapa futuro, sem compartilhar package com o mobile.
- [x] A estrutura lógica separa infraestrutura central, autenticação, dashboard, locais e usuários, mesmo que features futuras tenham placeholders mínimos.
- [x] Material 3, tema COMPY independente e strings PT-BR iniciais existem sem copiar arquivos do mobile.
- [x] Há tela inicial neutra enquanto Firebase é inicializado, sem shell administrativo ou consulta de dados.
- [x] Análise e testes do app administrativo passam; o mobile permanece analisável e seus testes não foram alterados.

## Verification

- [x] Executar análise e testes do app administrativo.
- [x] Executar build Web de desenvolvimento sem credenciais privadas.
- [x] Confirmar que não há importação de fontes do app mobile.

## Answer

Criada a aplicação Flutter Web independente em `admin/`, com bootstrap de Firebase, tema Material 3 próprio, fronteiras feature-first e testes da tela de inicialização. O painel ainda não possui autenticação administrativa, guard, shell ou consulta de dados; esses itens pertencem aos tickets posteriores.

Validação executada: `flutter analyze` no painel (sem issues), `flutter test` no painel (2 testes aprovados), `flutter build web` (bundle gerado) e busca por imports cruzados (nenhum encontrado). `flutter analyze` no mobile preservou apenas 10 avisos informativos existentes. A suíte mobile não pôde iniciar devido a um erro de quoting do hook `objective_c` para o caminho local com espaço; nenhum arquivo mobile foi modificado por este ticket.

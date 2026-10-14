# 05: Migrar mapa mobile para Locais Esportivos em tempo real

Status: resolved

Blocked by: 04 — Fornecer repository Firestore de Local Esportivo ao mobile

Spec: §§ 6, 10, 21 e Testing Decisions / Mobile.

**What to build:** O mapa e o detalhe de Local Esportivo passam a usar o repository Firestore em tempo real, exibindo somente ativos em descoberta e tratando explicitamente loading, vazio, erro, cache offline, pesquisa normalizada e contexto histórico inativo.

## Acceptance criteria

- [x] O mapa observa o stream de locais ativos e atualiza pins sem reinício.
- [x] Busca local filtra nome normalizado e modalidade sobre os dados ativos carregados.
- [x] Loading, vazio, erro e cache offline são visualmente distintos; erro não vira camada silenciosamente vazia de pins.
- [x] Deep link por ID resolve local inativo em contexto histórico ou mostra `Local não encontrado`/erro offline apropriado.
- [x] Detalhe histórico de inativo exibe o estado e desabilita criar evento e compartilhar.
- [x] UI de detalhes deixa de renderizar avaliações fictícias.
- [x] Nenhuma tela de mapa usa `SportPlace.all` ou `SportPlace.byId` como fonte de produção.
- [x] Testes de widget/repository cobrem fluxo ativo, inativo, erro, cache e pesquisa.

## Verification

- [x] Executar `flutter analyze` e testes mobile afetados.
- [x] Confirmar que atualização de snapshot muda o mapa sem reinício em teste de widget com stream.

Validação: análise Flutter do escopo alterado sem issues (exit code 0); suíte mobile completa com 190 testes aprovados (exit code 0); testes focados de mapa e repository aprovados. `git diff --check` aprovado.

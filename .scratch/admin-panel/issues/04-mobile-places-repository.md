# 04: Fornecer repository Firestore de Local Esportivo ao mobile

Status: resolved

Blocked by: 03 — Introduzir contrato de Local Esportivo, Rules transitórias e migração

Spec: §§ 5, 10, 21 e Testing Decisions / Mobile.

**What to build:** A camada mobile que entende o schema de Local Esportivo e oferece stream de locais ativos, filtro por modalidade, resolução histórica por ID e metadados de cache. Este ticket não migra ainda todas as telas para a nova fonte.

## Acceptance criteria

- [x] Modelo mobile representa endereço estruturado, `sports`, `primarySport`, status, coordenadas e imagem, sem campos fictícios de avaliação.
- [x] Normalização pt-BR e formatação de endereço têm comportamento testado e compatível com o contrato.
- [x] Repository Firestore observa somente locais ativos, ordenados por `nameLower`, e filtra por modalidade quando solicitado.
- [x] Repository resolve local ativo ou inativo por ID para referência histórica.
- [x] Chamadores distinguem dados de cache, dados confirmados, vazio e erro; não há cache persistente paralelo.
- [x] O novo repository não usa fallback estático; o catálogo legado permanece temporariamente apenas nos fluxos de evento/chat ainda não migrados pelos tickets 06/07/17.
- [x] Testes cobrem parsing, invalidez tolerada, ordenação, filtros, resolução inativa e metadados offline.

## Verification

- [x] Executar testes Dart afetados e `flutter analyze` no mobile.
- [x] Exercitar repository com fake da fonte de dados, cobrindo filtro, ordenação, resolução inativa e metadados; a suíte não contém um Firestore fake SDK nem integração Dart com Emulator.

## Answer

O modelo `SportPlace` agora representa o contrato Firestore, valida normalização
pt-BR, endereço estruturado, GeoPoint, modalidades, status e timestamps, e
ignora documentos inválidos sem interromper a leitura. `FirestorePlacesRemoteDataSource`
consulta `places` em stream com `status == active`, `orderBy(nameLower)` e filtro
`array-contains` quando solicitado; `PlacesRepositoryImpl` expõe os dados e a
origem cache/servidor, além da resolução por ID para locais inativos.

O novo caminho do mapa passou a consumir o stream Firestore. A compatibilidade
estática ainda é necessária temporariamente para o seletor de eventos e cards
de mensagem, que serão migrados nos tickets 06/07; sua remoção final continua
no ticket 17. A UI de locais deixou de exibir avaliações fictícias.

Verificação: 180 testes Flutter passaram (exit code 0); análise direcionada
dos 10 arquivos afetados não encontrou issues (exit code 0). A integração
mobile com Emulator não faz parte da suíte existente; o repository foi
exercitado com fake da camada remota. `git diff --check` passou.

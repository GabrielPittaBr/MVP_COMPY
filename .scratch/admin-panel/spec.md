# Painel Administrativo do COMPY e fonte unificada de Locais Esportivos

Status: ready-for-agent

## Problem Statement

O COMPY já possui um aplicativo Flutter mobile funcional, conectado ao Firebase Authentication e ao Firestore, mas ainda não possui um Painel Administrativo. A equipe não consegue cadastrar e manter Locais Esportivos sem publicar uma nova versão do aplicativo, porque a fonte de produção atual é o catálogo estático `SportPlace.all`, resolvido por `SportPlace.byId`. Essa fonte é acessada pelo mapa, pelo formulário de criação de Evento Esportivo e pelos cards de Mensagem de Local.

O modelo atual de `SportPlace` também contém campos fictícios de avaliação (`rating`, `ratingsCount` e `hasRatings`), usa a primeira posição de `allowedSports` como modalidade principal e representa endereço como texto simples. O Firestore não possui regras para `places`; a coleção cai no deny-by-default. Os seis índices compostos atuais atendem apenas conversas e eventos.

O contrato atual de Evento Esportivo grava `location`, `coordinates` e `geohash`, mas não grava `placeId` nem um snapshot histórico do Local Esportivo. O envio de Mensagem de Local grava somente `placeId`, e a renderização depende de o identificador ainda existir no catálogo estático. A criação de eventos e o compartilhamento de locais não validam o estado mais recente do local no Firestore.

Os perfis públicos atuais em `users/{uid}` contêm `id`, `name`, `handle`, `avatarUrl`, `createdAt` e, depois do onboarding, `favoriteSports`. O e-mail fica em `users/{uid}/private/contact`. A busca existente consulta apenas prefixo de `handle`; não existe `nameLower`. As regras atuais ainda permitem que o dono regrave `handle` e `createdAt`, por compatibilidade com o fluxo de cadastro existente.

É necessário criar uma aplicação administrativa profissional e demonstrável para o TCC, sem ampliar o escopo para uma plataforma operacional complexa. O Painel Administrativo deve gerenciar Locais Esportivos diretamente no Firestore, consultar informações mínimas de Usuários e realizar Suspensão Administrativa por uma fronteira confiável baseada em Callable Cloud Functions e Firebase Admin SDK. O mobile, o painel, as Security Rules, os índices e os scripts de migração devem convergir para um único contrato de dados, preservando eventos e mensagens legados.

## Solution

Criar uma aplicação Flutter Web independente na raiz `admin/`, usando o mesmo projeto Firebase `compy-tcc`, sem compartilhar código diretamente com o mobile. O painel terá autenticação por e-mail e senha, exigirá e-mail verificado e custom claim booleana `admin: true`, e oferecerá somente Dashboard, Locais e Usuários.

Migrar Locais Esportivos para a coleção `places`, com schema estrito, status `active` ou `inactive`, endereço estruturado, modalidades explícitas, coordenadas geográficas, imagem HTTPS e timestamps de servidor. O painel administrará essa coleção diretamente, protegido por custom claim, Security Rules, validação de schema e testes no emulador. O mobile passará a observar locais ativos por streams do Firestore e a consultar locais inativos individualmente quando precisar resolver referências históricas.

Adicionar `placeId` e snapshots imutáveis a novos Eventos Esportivos e Mensagens de Local. As Rules validarão o documento atual de `places` no momento do commit. A migração seguirá expand–contract para permitir uma janela curta de convivência entre o escritor antigo e o novo, sem migrar destrutivamente eventos ou mensagens legados.

Adicionar três Callable Cloud Functions de segunda geração em TypeScript e `southamerica-east1`: consulta de detalhes Auth, consulta em lote do estado Auth e suspensão/reativação idempotente. As Functions exigirão autenticação, custom claim administrativa e App Check. Dados públicos de Perfil de Usuário continuarão sendo lidos diretamente do Firestore; e-mail confiável, metadados Auth e mutações de Conta de Usuário permanecerão atrás do Admin SDK.

Hospedar o painel em um target dedicado do Firebase Hosting, com rotas sem `#`, rewrite para `index.html`, domínio padrão do Firebase e deploy manual documentado. O plano Blaze será um pré-requisito explícito para as Functions, acompanhado de recomendação de orçamento e alertas de custo.

## User Stories

1. Como Administrador, quero entrar no Painel Administrativo com e-mail e senha, para acessar ferramentas internas sem cadastro público.
2. Como Administrador, quero que o painel verifique meu e-mail e minha custom claim antes de renderizar conteúdo, para que dados administrativos não sejam carregados prematuramente.
3. Como usuário sem permissão administrativa, quero receber uma mensagem clara de acesso não autorizado e ser desconectado, para entender por que não posso acessar o painel.
4. Como Administrador, quero que deep links passem pelo mesmo guard de autorização, para que uma URL direta não contorne a proteção.
5. Como responsável técnico, quero atribuir `admin: true` manualmente a um UID qualificado, para criar o primeiro Administrador sem expor uma API pública de bootstrap.
6. Como responsável técnico, quero que o bootstrap recuse contas sem provedor de senha ou sem e-mail verificado, para não criar um acesso administrativo incompatível com o login do painel.
7. Como Administrador, quero que minha sessão dure somente enquanto a sessão do navegador estiver aberta, para reduzir o risco em computadores compartilhados.
8. Como Administrador, quero ver um Dashboard com perfis cadastrados, locais ativos e locais inativos, para compreender rapidamente o estado operacional do COMPY.
9. Como Administrador, quero atalhos para cadastrar local, visualizar inativos e buscar usuário, para chegar rapidamente às tarefas principais.
10. Como Administrador, quero saber que “Usuários cadastrados” conta perfis Firestore, para não confundir esse indicador com todas as contas existentes no Firebase Auth.
11. Como Administrador, quero listar Locais Esportivos em ordem alfabética e em páginas de 20 itens, para trabalhar com um catálogo crescente.
12. Como Administrador, quero pesquisar locais por prefixo do nome normalizado, para encontrá-los sem depender de caixa ou acentos.
13. Como Administrador, quero filtrar locais por status, modalidade e cidade, isoladamente ou em conjunto, para localizar o subconjunto relevante.
14. Como Administrador, quero ver alterações do Firestore refletidas nas listagens sem reiniciar o painel, para não trabalhar sobre uma visão silenciosamente obsoleta.
15. Como Administrador, quero cadastrar um Local Esportivo inicialmente inativo, para revisar o conteúdo antes de disponibilizá-lo no mobile.
16. Como Administrador, quero editar nome, descrição, endereço, modalidades, coordenadas e imagem de um local, para manter o catálogo correto.
17. Como Administrador, quero escolher uma modalidade principal explicitamente, para que ícone e representação não dependam da ordem da lista.
18. Como Administrador, quero selecionar coordenadas no mapa e também editar latitude e longitude, para cadastrar o ponto com precisão.
19. Como Administrador, quero receber um aviso para coordenadas muito distantes de Taquara, sem bloqueio rígido, para detectar enganos sem impedir exceções legítimas.
20. Como Administrador, quero visualizar a imagem HTTPS antes de salvar, para detectar URLs inválidas ou inadequadas.
21. Como Administrador, quero ativar e desativar um local por ações separadas da edição, para compreender o impacto operacional da mudança.
22. Como Administrador, quero uma confirmação explícita antes de desativar um local, para saber que ele deixará de aceitar novos usos.
23. Como Administrador, quero reativar um local preservado, para restaurar sua descoberta e seu uso normal.
24. Como Administrador, quero que uma edição baseada em versão antiga seja rejeitada, para não sobrescrever silenciosamente a alteração de outro Administrador.
25. Como usuário mobile, quero ver somente locais ativos no mapa e nas pesquisas comuns, para não escolher locais indisponíveis.
26. Como usuário mobile, quero filtrar os locais ativos por modalidade e nome, para encontrar espaços compatíveis com meu interesse.
27. Como usuário mobile, quero receber atualizações dos locais em tempo real, para não precisar reiniciar o aplicativo depois de uma alteração administrativa.
28. Como usuário mobile, quero que um Local Esportivo Inativo continue resolvível em contexto histórico, para compreender eventos e mensagens antigos.
29. Como usuário mobile, quero ver “Local inativo” e não receber ação de criar evento nesse local, para distinguir histórico de disponibilidade atual.
30. Como criador de Evento Esportivo, quero selecionar somente locais ativos e modalidades suportadas, para não criar um evento incompatível.
31. Como criador de Evento Esportivo, quero ser avisado se o local mudar ou for desativado antes do envio, para revisar a seleção sem perder os demais campos.
32. Como participante, quero que um evento preserve nome, endereço e coordenadas do local usados na criação, para que alterações futuras não reescrevam seu contexto histórico.
33. Como usuário de uma versão atual, quero continuar lendo eventos antigos sem `placeId`, para que a migração não destrua o histórico.
34. Como usuário do chat, quero compartilhar somente um local ativo e atual, para não criar uma nova referência inválida.
35. Como leitor de uma Mensagem de Local, quero usar os dados atuais quando disponíveis e um snapshot quando não estiverem, para que o card continue compreensível.
36. Como leitor de uma mensagem legada que contém apenas `placeId`, quero um fallback genérico quando o local não puder ser resolvido, para que a conversa não quebre.
37. Como usuário mobile sem conexão, quero conservar o formulário de evento ou compartilhamento preparado, para tentar novamente depois de reconectar.
38. Como usuário mobile sem conexão, quero que criação de evento e compartilhamento de local não sejam enfileirados, para não criar vínculos usando estado antigo.
39. Como usuário mobile offline com cache, quero ver dados disponíveis com indicação discreta de offline, para saber que podem estar desatualizados.
40. Como usuário mobile sem cache, quero distinguir erro de carregamento de resultado vazio, para saber quando devo tentar novamente.
41. Como Administrador, quero buscar Usuários escolhendo explicitamente Nome, Handle, UID ou E-mail, para que o comportamento da consulta seja previsível.
42. Como Administrador, quero pesquisa paginada por prefixo para Nome e Handle, para não carregar todos os perfis no navegador.
43. Como Administrador, quero consulta exata por UID ou E-mail, para encontrar uma Conta de Usuário específica.
44. Como Administrador, quero ver avatar, nome, handle, modalidades favoritas e estado da conta na lista, para fazer uma triagem mínima.
45. Como Administrador, quero ver UID, e-mail, verificação, provedores, criação e último login no detalhe, para investigar uma conta sem expor dados desnecessários.
46. Como Administrador, quero visualizar uma conta Auth sem perfil como “Perfil não encontrado”, para ainda poder administrar seu acesso.
47. Como Administrador, quero visualizar um perfil sem conta Auth como “Conta não encontrada”, para não oferecer uma ação impossível.
48. Como Administrador, quero que uma falha ao obter estados Auth seja exibida como “Estado indisponível”, para nunca presumir incorretamente que uma conta está ativa.
49. Como Administrador, quero suspender uma Conta de Usuário com motivo obrigatório e confirmação final, para restringir novos acessos de forma rastreável.
50. Como Administrador, quero reativar uma Conta de Usuário com motivo obrigatório e confirmação final, para restaurar seu acesso de forma rastreável.
51. Como Administrador, quero ser impedido de alterar minha própria conta ou outra conta administrativa, para reduzir o risco de perda de acesso privilegiado.
52. Como Administrador, quero que a repetição da mesma operação retorne o resultado conhecido, para poder tentar novamente com segurança após uma falha de rede.
53. Como responsável técnico, quero registros `pending`, `succeeded` e `failed`, para reconciliar a fronteira não transacional entre Firebase Auth e Firestore.
54. Como responsável técnico, quero que uma operação `pending` seja reconciliada somente quando repetida, para evitar scheduler e infraestrutura de jobs no MVP.
55. Como responsável técnico, quero que credenciais de Admin SDK permaneçam fora do Git, para não expor controle privilegiado do projeto.
56. Como responsável técnico, quero proteger Functions com Auth, claim e App Check, para aplicar defesa em profundidade.
57. Como responsável técnico, quero publicar Rules e índices antes dos novos escritores, para que o deploy não produza falhas por dependências ausentes.
58. Como responsável técnico, quero migrar `parque_do_trabalhador` por um script idempotente, para preservar seu identificador e evitar duplicação.
59. Como responsável técnico, quero validar o escritor novo antes de endurecer as Rules finais, para executar o expand–contract com rollback possível.
60. Como avaliador do TCC, quero um painel responsivo, consistente e acessível, para demonstrar uma solução profissional sem funcionalidades supérfluas.

## Implementation Decisions

### 1. Estado atual confirmado

- O aplicativo Flutter mobile existe na raiz e usa arquitetura feature-first, Riverpod, GoRouter, Firebase Auth, Firestore e `flutter_map`.
- `SportPlace` é a entidade atual de local. Ela contém `id`, `name`, `city`, `address` textual, `coordinates`, `allowedSports`, `imageUrl`, `description`, `rating` e `ratingsCount`; `primarySport` deriva do primeiro item e `hasRatings` deriva da contagem.
- `SportPlace.all` contém somente `parque_do_trabalhador`; `SportPlace.byId` faz resolução estática. `MockPlaces` e `EventLocation.all` não existem no código atual.
- `PlacesRepository` expõe `getAll` e `getBySport` como `Future`; sua implementação ignora o Firebase e devolve o catálogo estático. O provider do mapa é um `FutureProvider`.
- O mapa resolve deep links por `SportPlace.byId`, transforma erro de carregamento em camada vazia de pins e ainda possui campo de pesquisa sem comportamento real.
- O formulário atual de Evento Esportivo lista `SportPlace.all`, restringe a modalidade por `allowedSports` e grava texto `"nome, cidade"`, coordenadas e geohash. A criação remota usa `add` direto, não uma transação de validação do local.
- `Event` ainda não possui `placeId` ou `placeSnapshot`. Sua leitura tolerante já fornece uma base adequada para manter documentos legados.
- `Message` e `MessageMapper` possuem somente `placeId` opcional. O batch de envio grava a mensagem e atualiza o rodapé da conversa; o card resolve o local por `SportPlace.byId`.
- Perfis públicos são escritos diretamente pelo mobile. O fluxo atual não grava `nameLower`; o e-mail é separado em `users/{uid}/private/contact`. A busca remota existente usa prefixo de `handle`.
- As Rules não têm bloco de `places`. A criação de evento não consulta local; a criação de mensagem valida associação à conversa e remetente, mas não valida Local Esportivo. `ratings` ainda aceita `targetType: place`.
- Os índices atuais são seis: um de conversas e cinco de eventos. Não existem índices de `places`.
- O projeto Firebase e o app Web já estão registrados. Não existem ainda a aplicação `admin/`, o projeto de Functions nem a configuração de Hosting. O App Check mobile ativa provider Android; a configuração Web do painel ainda será criada.
- A implementação deve preservar a intenção aprovada e adaptar esses pontos; a spec não presume que o estado alvo já existe.

### 2. Forma do repositório e módulos

- O aplicativo mobile atual permanece na raiz sem reorganização de monorepo.
- O Painel Administrativo será uma aplicação Flutter Web independente com raiz `admin/`, `pubspec` e configuração FlutterFire próprios.
- Não haverá package compartilhado de domínio. Mobile e painel terão modelos próprios que implementam o mesmo contrato Firestore.
- O painel seguirá uma organização feature-first compatível com o estilo do projeto, com módulos lógicos de autenticação, dashboard, locais e usuários, além de infraestrutura central de Firebase, roteamento, tema e tratamento de erros.
- O painel usará Material 3, Riverpod e GoRouter. O seletor geográfico usará mapa OpenStreetMap por uma dependência Flutter Web estável; não haverá geocodificação.
- Um projeto TypeScript separado de Firebase Functions de segunda geração será adicionado ao repositório.
- Scripts privilegiados de bootstrap e migração ficarão em um pacote de tooling versionado, separado dos dois clientes. Eles usarão Admin SDK e Application Default Credentials ou caminho de credencial fornecido externamente.
- Service accounts, chaves privadas, tokens de debug e arquivos `.env` com segredo continuarão fora do Git.

### 3. Rotas, shell e autorização do painel

- Rotas públicas: `/login` e `/unauthorized`.
- Rotas administrativas: `/dashboard`, `/places`, `/places/new`, `/places/:id`, `/users` e `/users/:uid`.
- O app inicializa Firebase e resolve o estado Auth em uma tela integral de carregamento, força atualização do ID token e lê as claims antes de construir shell ou providers de dados administrativos.
- Autorização exige simultaneamente: usuário autenticado, provedor compatível com login por senha, e-mail verificado e `token.claims.admin === true`.
- Ausência ou falsidade da claim causa limpeza dos estados administrativos, logout imediato e navegação para `/unauthorized`. A tela oferece retorno para `/login`.
- Todo deep link administrativo passa pelo mesmo guard. O guard deve ser testável como decisão pura de redirecionamento, seguindo o prior art do router mobile.
- A persistência Auth Web será `SESSION`; fechar a sessão do navegador remove a sessão local.
- O shell será desktop-first: sidebar permanente em largura ampla, sidebar recolhível em largura menor, cabeçalho com título e conta administrativa, e logout sempre acessível. Não haverá bottom navigation.

### 4. Bootstrap do primeiro Administrador

- O script recebe exatamente um UID existente.
- Antes de atribuir a claim, busca a conta pelo Admin SDK e exige `emailVerified === true` e presença do provider `password`/`password.providerId` equivalente a `password`.
- O script recusa UID inexistente, conta desabilitada, ausência de e-mail, e-mail não verificado ou ausência do provedor de senha. Não altera senha, providers nem `emailVerified`.
- Quando válido, preserva quaisquer custom claims não relacionadas e grava `admin: true`.
- O script possui modo de verificação/dry-run, saída sem dados sensíveis e execução idempotente: claim já presente é sucesso sem alteração.
- Depois do bootstrap, o Administrador deve sair e entrar novamente, ou forçar renovação do token, para receber a nova claim.
- Não haverá endpoint de bootstrap, documento `admins/{uid}` nem gestão de administradores no painel.

### 5. Contrato definitivo de `places`

`places/{placeId}` usa o ID do documento como identidade; não armazena um campo `id` duplicado. Novos documentos usam auto-ID. O schema persistido é completo e possui whitelist exata:

| Campo | Tipo | Obrigatoriedade e invariantes |
| --- | --- | --- |
| `name` | string | Obrigatório, trim aplicado, 3–120 caracteres. |
| `nameLower` | string | Obrigatório, resultado de `TextNormalizer`: trim, minúsculas e remoção de acentos comuns pt-BR. |
| `description` | string | Obrigatório, trim aplicado, 20–1.500 caracteres. |
| `address` | map | Obrigatório e com whitelist própria. |
| `address.street` | string | Obrigatório, não vazio, máximo 160 caracteres. |
| `address.city` | string | Obrigatório, não vazio, máximo 100 caracteres. |
| `address.cityLower` | string | Obrigatório, derivado de `address.city` pelo mesmo normalizador. |
| `address.state` | string | Obrigatório, uma UF brasileira válida, em maiúsculas. |
| `address.number` | string | Opcional; quando presente, trim, 1–20 caracteres. Ausência representa “sem número”. |
| `address.complement` | string | Opcional; quando presente, trim, 1–120 caracteres. |
| `address.neighborhood` | string | Opcional; quando presente, trim, 1–100 caracteres. |
| `address.postalCode` | string | Opcional; quando presente, exatamente 8 dígitos, sem máscara. |
| `sports` | list de string | Obrigatório, 1–8 itens, sem duplicatas, somente valores suportados. |
| `primarySport` | string | Obrigatório, valor suportado e presente em `sports`. |
| `coordinates` | GeoPoint | Obrigatório, latitude entre -90 e 90 e longitude entre -180 e 180. |
| `imageUrl` | string | Obrigatório, URL HTTPS, máximo 2.048 caracteres. |
| `status` | string | Obrigatório, somente `active` ou `inactive`. |
| `createdAt` | Timestamp | Obrigatório, timestamp do servidor e imutável. |
| `updatedAt` | Timestamp | Obrigatório, timestamp do servidor atualizado em toda mutação. |

- Campos opcionais vazios são omitidos, não armazenados como `null` ou string vazia.
- Modalidades válidas: `futebol`, `basquete`, `volei`, `tenisDeMesa`, `futsal`, `corrida`, `ciclismo` e `caminhada`.
- O contrato não contém `rating`, `ratingsCount`, `hasRatings`, galeria, Storage, `createdBy` ou `updatedBy`.
- Todo novo documento nasce `inactive`; não existe segundo schema de rascunho.
- Documentos ativos e inativos obedecem ao mesmo schema completo. `imageUrl` válida é obrigatória também no estado inativo.
- Ativação e desativação são ações explícitas e separadas da edição de conteúdo.
- Não existe exclusão física no painel. Intervenção técnica excepcional deve verificar referências antes de qualquer remoção.
- O normalizador Dart já existente no mobile é a referência comportamental. O painel reimplementará o mesmo algoritmo e ambos terão testes vetoriais idênticos. Como Firestore Rules não consegue reproduzir de forma confiável toda remoção de diacríticos, a equivalência exata de `nameLower` e `cityLower` será garantida pelos clientes administrativos, scripts confiáveis e testes; as Rules validarão presença, tipo, limites, whitelist e imutabilidades aplicáveis.

### 6. Administração de Locais Esportivos

- A lista permite busca por prefixo de `nameLower`, filtros combináveis por `status`, `sports` com `array-contains` e `address.cityLower`, ordenação crescente por `nameLower` e páginas de 20 documentos.
- O cursor é o último `DocumentSnapshot` confirmado da página anterior. Mudar busca, filtro ou ordenação limpa páginas e cursor.
- Leituras relevantes usam snapshots em tempo real. Alterações por ID são reconciliadas na lista; quando uma alteração invalida a fronteira de paginação, o controller reinicia a consulta a partir da primeira página em vez de manter duplicatas ou lacunas silenciosas.
- O formulário possui validação inline depois da interação, resumo de erros no submit, preview de imagem, mapa, latitude e longitude numéricas e representação clara do ponto.
- Coordenadas muito distantes do centro de Taquara geram aviso não bloqueante.
- Criação persiste o documento completo como `inactive` e só informa sucesso depois da confirmação do servidor.
- Edição, ativação, desativação e reativação usam transação online. A transação compara o `updatedAt` carregado pelo formulário com o valor atual; divergência gera conflito, preserva os campos digitados e oferece recarregar.
- O painel não oferece suporte intencional a mutações offline, não mantém fila própria e não apresenta sucesso enquanto houver apenas escrita local pendente.
- Desativação exige confirmação explicando que o local sairá do mapa, pesquisas e criação de eventos, mas continuará resolvível historicamente.
- Sair com alterações não salvas exige confirmação. Botões de submit e de status permanecem desabilitados durante a operação.

### 7. Leitura e autorização de `places`

- Usuário autenticado do mobile pode listar somente documentos cujo `status` é `active`; as queries mobile sempre incluem esse filtro.
- Usuário autenticado pode fazer `get` por ID de local ativo ou inativo para resolver contexto histórico.
- Administrador com `request.auth.token.admin == true` pode listar ativos e inativos.
- Somente Administrador pode criar ou atualizar.
- `delete` é sempre negado.
- Create exige whitelist completa, `status == inactive`, `createdAt == request.time` e `updatedAt == request.time`.
- Update exige schema completo válido, `createdAt` igual ao valor anterior e `updatedAt == request.time`.
- A validação cobre tipos, limites, UFs, CEP, URL HTTPS, modalidades permitidas, ausência de duplicatas, inclusão de `primarySport`, GeoPoint e status.
- Nenhuma permissão de cliente será concedida aos registros administrativos de suspensão.
- Os testes de Rules devem usar contextos deslogado, usuário comum, Administrador e documentos malformados. Queries devem ser testadas com os filtros exatos exigidos pelas Rules.

### 8. Consultas e índices compostos

As buscas por prefixo usam `orderBy`, `startAt(prefix)` e `endAt(prefix + U+F8FF)`. Paginação acrescenta `startAfterDocument` e `limit(20)`. `nameLower`, `address.cityLower` e `handle` usam índices de campo único automáticos quando não há outro filtro.

O arquivo de índices resultante preservará os seis índices atuais e adicionará sete para `places`.

Índices atuais preservados:

1. `conversations`: `members` ARRAY_CONTAINS, `lastMessageAt` DESC.
2. `events`: `sport` ASC, `dateTime` ASC.
3. `events`: `skillLevel` ASC, `dateTime` ASC.
4. `events`: `sport` ASC, `skillLevel` ASC, `dateTime` ASC.
5. `events`: `creator.id` ASC, `dateTime` ASC.
6. `events`: `participantIds` ARRAY_CONTAINS, `dateTime` ASC.

Novos índices de `places`, todos com query scope de coleção:

7. `status` ASC, `nameLower` ASC.
8. `sports` ARRAY_CONTAINS, `nameLower` ASC.
9. `address.cityLower` ASC, `nameLower` ASC.
10. `sports` ARRAY_CONTAINS, `status` ASC, `nameLower` ASC.
11. `status` ASC, `address.cityLower` ASC, `nameLower` ASC.
12. `sports` ARRAY_CONTAINS, `address.cityLower` ASC, `nameLower` ASC.
13. `sports` ARRAY_CONTAINS, `status` ASC, `address.cityLower` ASC, `nameLower` ASC.

- O índice 7 atende também a listagem mobile de locais ativos.
- O índice 10 atende mobile com status ativo e filtro por modalidade.
- Contagens agregadas por status usam índice de campo único e não exigem índice adicional.
- Busca de Perfil de Usuário por `nameLower` ou `handle` usa uma única ordenação e não exige índice composto no escopo atual.
- Qualquer alteração futura da matriz de filtros deve acrescentar o índice necessário ao arquivo versionado, nunca depender de criação manual não documentada pelo Console.

### 9. Migração de `parque_do_trabalhador`

- Um script Admin SDK idempotente cria exatamente `places/parque_do_trabalhador`; esse ID é a exceção legada e não será usado como padrão para novos locais.
- Dados iniciais:
  - `name`: `Parque do Trabalhador`;
  - `nameLower`: `parque do trabalhador`;
  - `description`: a descrição atual do catálogo;
  - `address.street`: `Rua Ernesto Alves`;
  - `address.neighborhood`: `Recreio`;
  - `address.city`: `Taquara`;
  - `address.cityLower`: `taquara`;
  - `address.state`: `RS`;
  - `address.postalCode`: `95600354`;
  - `address.number` e `address.complement`: omitidos;
  - `coordinates`: latitude `-29.656276729317323`, longitude `-50.787726691670045`;
  - `sports`: `futebol`, `basquete`, `futsal`, `volei`, `corrida`, `ciclismo`, `caminhada`;
  - `primarySport`: `futebol`;
  - `imageUrl`: a URL HTTPS atualmente usada pelo catálogo;
  - `status`: `active`;
  - timestamps: servidor.
- O endereço deve ser conferido contra a fonte oficial antes da execução em produção; a execução não faz geocodificação.
- Se o documento não existir, o script o cria. Se já for equivalente, encerra com sucesso sem escrever. Se existir com divergência, aborta e apresenta o diff; não sobrescreve silenciosamente.
- O script possui dry-run, valida o schema localmente e nunca contém service account.
- A verificação pós-migração confirma leitura direta, query de ativos, filtro por cada modalidade, ordenação, tipos e timestamps.

### 10. Integração mobile com `places`

- `SportPlace` será adaptado ao contrato Firestore ou substituído por uma entidade equivalente, preservando o nome público somente se isso minimizar mudanças. O modelo deixa de conter avaliações e passa a conter endereço estruturado, `sports`, `primarySport`, `status`, `createdAt` e `updatedAt`.
- O contrato de repository passa a expor:
  - stream de locais ativos, opcionalmente filtrado por modalidade e ordenado por `nameLower`;
  - consulta por ID que aceita local inativo;
  - metadados suficientes para distinguir cache e servidor.
- A implementação Firestore substitui o catálogo estático na produção. Fixtures estáticas permanecem somente em testes ou no modo explicitamente mockado.
- O mapa observa o stream ativo, aplica busca local por nome normalizado e modalidade, e não converte erro em lista vazia de pins.
- Com cache e sem conexão, o mapa mostra os dados e um indicador discreto de offline. Sem cache, mostra erro com `Tentar novamente`. Resultado confirmado sem locais usa estado vazio distinto.
- Deep link e Mensagem de Local consultam por ID. Documento inexistente online exibe `Local não encontrado`; falha sem rede e sem cache exibe `Não foi possível carregar o local`.
- Local inativo em contexto histórico recebe rótulo `Local inativo`; criar evento e compartilhar ficam indisponíveis.
- O seletor de local no formulário de evento observa o stream de ativos. Se o local selecionado for desativado, os demais campos permanecem e somente a seleção do local é invalidada.
- Depois de validar a leitura Firestore em produção, `SportPlace.all` e `SportPlace.byId` deixam de ser fontes de produção. Testes atuais que afirmam que o catálogo estático nunca é vazio serão reescritos para o repository/fixture novo.
- Não haverá cache persistente paralelo ao cache nativo do Firestore.

### 11. Novo contrato de Evento Esportivo

Novos documentos de `events` mantêm os campos atuais e acrescentam:

| Campo | Tipo | Regra |
| --- | --- | --- |
| `placeId` | string | Obrigatório em novas criações após o contract; ID de `places`. |
| `placeSnapshot.name` | string | Igual ao `name` atual do local no commit. |
| `placeSnapshot.address` | map | Cópia estruturada exata do endereço atual. |
| `placeSnapshot.coordinates` | GeoPoint | Igual às coordenadas atuais. |

- `coordinates` continua no nível superior e deve ser igual a `placeSnapshot.coordinates`.
- `geohash` continua no nível superior e é calculado a partir dessas coordenadas.
- `location` textual continua sendo gravado para compatibilidade com builds antigos; é formatado de forma determinística a partir do snapshot.
- `sport` deve existir em `places/{placeId}.sports`.
- Criação remota usa transação Firestore: lê o local, exige `active`, constrói/valida o snapshot com o documento lido e cria o evento. Transações falham offline, portanto a ação não é enfileirada.
- As Rules repetem a autoridade no commit usando `get()` do local. O local deve existir, estar ativo, suportar `sport`, e os campos do snapshot devem ser iguais aos atuais.
- Depois da criação, `sport`, `placeId` e `placeSnapshot` são imutáveis, inclusive em edições do criador. Join continua alterando somente participantes, IDs e vagas.
- Se nome, endereço, coordenadas ou modalidades mudarem entre seleção e commit, a escrita falha. O cliente recarrega o local, explica que houve alteração e exige nova revisão antes do reenvio.
- Evento criado antes da desativação permanece válido e histórico. Desativação confirmada antes do commit impede a criação.
- Documentos legados sem `placeId` e `placeSnapshot` continuam legíveis. Updates permitidos nesses documentos preservam a ausência dos campos e tornam `sport` imutável; não haverá migração destrutiva ou snapshot retroativo inventado.

### 12. Novo contrato de Mensagem de Local

Nova Mensagem de Local mantém os campos atuais e acrescenta `placeSnapshot` com whitelist exata:

- `name`;
- `imageUrl`;
- `primarySport`.

Regras e fluxo:

- Mensagem de texto comum não contém `placeId` nem `placeSnapshot` e conserva o comportamento atual.
- Nova Mensagem de Local contém `placeId` não vazio e snapshot completo correspondente ao documento atual.
- O envio usa uma transação Firestore online: lê o local atual, exige `active`, deriva o snapshot dessa leitura e grava mensagem e rodapé da conversa atomicamente. A transação falha offline e não é enfileirada; não usar WriteBatch neste fluxo, pois batches do SDK podem ser aplicados/enfileirados offline ([semântica oficial de transações e batches](https://firebase.google.com/docs/firestore/manage-data/transactions)).
- As Rules consultam `places/{placeId}` no commit, exigem local ativo, remetente correto, associação à conversa e snapshot exato.
- Sem conexão, o compartilhamento não é enfileirado. O seletor/conteúdo permanece aberto e informa que é necessário reconectar.
- Na leitura, o card tenta resolver o documento atual. Se acessível, usa nome, imagem, modalidade e status atuais. Se não puder carregar, usa o snapshot.
- Local atual inativo abre detalhe histórico, mostra o estado e não oferece novo evento ou novo compartilhamento.
- Mensagens legadas que possuem somente `placeId` continuam legíveis. Quando não houver documento nem snapshot, exibem fallback visual genérico, sem quebrar a conversa.
- Mensagens já enviadas permanecem imutáveis.

### 13. Migração expand–contract de eventos e mensagens

1. Publicar índices e Rules transitórias que aceitem tanto o escritor legado quanto o novo, preservando todas as negações atuais de acesso indevido.
2. Migrar e verificar `places/parque_do_trabalhador`.
3. Publicar o mobile novo que lê `places` e grava `placeId` e snapshots.
4. Validar em ambiente real: mapa, seleção, criação de evento, join, compartilhamento, mensagem legada, local desativado e conflitos.
5. Medir/adotar o novo build durante uma janela curta.
6. Publicar Rules finais que exijam o novo contrato em toda nova criação de evento e Mensagem de Local.
7. Remover a fonte estática de produção após a confirmação da coleção Firestore.

- Depois do contract, builds antigos podem continuar lendo dados compatíveis, mas não precisam conseguir criar evento nem compartilhar local com o contrato antigo.
- A leitura de documentos legados não depende da aceitação de novas escritas legadas.
- Não remover `location` textual neste MVP.

### 14. Perfil de Usuário e pesquisa administrativa

- A listagem administrativa é originada exclusivamente de `users/{uid}`, com 20 perfis por página e cursor Firestore.
- Campos públicos usados: `id`/UID do documento, `name`, `nameLower`, `handle`, `avatarUrl`, `favoriteSports` e `createdAt` quando disponível.
- `nameLower` será obrigatório nos novos perfis e derivado pelo normalizador pt-BR.
- Um script idempotente faz backfill de `nameLower` para perfis existentes. Documento sem `name` válido é reportado para correção manual, não recebe valor inventado.
- O fluxo mobile de criação/regravação de perfil passa a escrever `nameLower` junto com `name`.
- `handle` e `createdAt` ficam imutáveis após a criação. Regravações do cadastro que enviem o mesmo valor continuam permitidas; alteração é recusada.
- A integridade exata de `nameLower` na criação é garantida pelo normalizador do cliente e pelo script; Rules validam campo, tipo, limites e sua atualização conjunta com `name`, dentro das capacidades da linguagem de Rules.
- Seletor explícito de pesquisa:
  - Nome: query paginada por prefixo de `nameLower`;
  - Handle: query paginada por prefixo de `handle`, após trim, minúsculas e tratamento do `@`;
  - UID: chamada exata a `getAdminUserAuthDetails` e leitura opcional de `users/{uid}`;
  - E-mail: chamada exata a `getAdminUserAuthDetails`, seguida de leitura opcional de `users/{uid}` retornado.
- Não há inferência de tipo, varredura local de todos os perfis ou consultas paralelas ocultas.
- Cada página de perfis faz uma única chamada a `getAdminUsersAuthStatus` com até 20 UIDs.
- A lista mostra avatar, nome, handle, modalidades favoritas e estado Auth.
- O detalhe acrescenta UID, e-mail principal, e-mail verificado, providers relevantes, criação Auth, último login e estado.
- O painel nunca retorna senha, hash, token, refresh token, detalhes internos desnecessários de provider, documentos privados genéricos, conversas ou mensagens.

### 15. Contas e perfis ausentes

- Conta Auth sem `users/{uid}` pode ser encontrada somente por consulta exata de UID ou e-mail. O detalhe mostra os dados Auth e `Perfil não encontrado`.
- Conta Auth sem perfil pode ser suspensa ou reativada se não for administrativa.
- Perfil Firestore sem conta Auth aparece na listagem com `Conta não encontrada`. O detalhe mantém apenas dados públicos e não oferece suspensão/reativação.
- Se a chamada em lote falhar, todos os estados daquela página aparecem como `Estado indisponível`; o painel nunca assume `active`.
- UIDs inexistentes em `getAdminUsersAuthStatus` são omitidos da resposta. O cliente diferencia omissão de falha total.
- O cartão “Usuários cadastrados” usa `count()` sobre `users` e representa perfis Firestore, não todas as contas Auth.

### 16. Fronteira de segurança para Usuários

- O painel pode ler os perfis públicos diretamente conforme as Rules.
- O painel não recebe permissão para escrever `users/{uid}`, `users/{uid}/private/*`, `usernames` ou dados Auth.
- E-mail confiável, providers, `emailVerified`, criação Auth, último login e `disabled` vêm exclusivamente do Admin SDK pelas Callables.
- Toda mutação de Conta de Usuário passa por `setUserSuspension`.
- Não há espelho de `disabled` no perfil público.
- Não há Function administrativa genérica.

### 17. Contratos das Callable Functions

Todas as Functions são Callable de segunda geração, TypeScript, região `southamerica-east1`. Todas exigem `request.auth != null`, `request.auth.token.admin === true` e App Check válido em produção. Claims são verificadas no servidor em toda chamada.

#### `getAdminUserAuthDetails`

Entrada JSON com whitelist exata e exatamente um identificador:

- `{ "uid": string }`; ou
- `{ "email": string }`.

Validação:

- rejeitar ambos, nenhum ou campos adicionais;
- UID não vazio e dentro dos limites do Firebase Auth;
- e-mail com trim, minúsculas e formato válido;
- busca exata, nunca prefixo.

Saída:

- `uid`;
- `email` principal ou `null` quando Auth não tiver e-mail;
- `emailVerified`;
- `providerIds`, lista deduplicada apenas dos IDs relevantes;
- `createdAt`, ISO-8601 UTC ou `null`;
- `lastSignInAt`, ISO-8601 UTC ou `null`;
- `disabled`.

Conta inexistente retorna `not-found`. A Function não lê nem retorna o perfil público.

#### `getAdminUsersAuthStatus`

Entrada:

- `{ "uids": string[] }`, entre 1 e 20 itens;
- sem campos adicionais;
- UIDs não vazios e sem duplicatas.

Saída:

- `{ "items": [{ "uid": string, "disabled": boolean }] }`;
- mantém a ordem dos UIDs encontrados;
- omite contas inexistentes;
- não retorna e-mail, providers ou metadados adicionais.

#### `setUserSuspension`

Entrada com whitelist exata:

- `uid`;
- `action`: `suspend` ou `reactivate`;
- `reason`;
- `operationId`.

Normalização e validação:

- `reason` recebe trim e colapso de espaços internos; deve ter 10–500 caracteres depois da normalização;
- `operationId` é UUID v4 gerado pelo painel;
- a Function rejeita conta inexistente, UID do próprio Administrador e qualquer alvo com custom claim `admin === true`;
- `suspend` para conta já desabilitada e `reactivate` para conta já habilitada são `failed-precondition` quando se trata de uma operação nova;
- conta Auth sem perfil continua elegível;
- perfil sem conta Auth retorna `not-found`.

Saída de sucesso:

- `uid`;
- `disabled` final;
- `action` executada;
- `completedAt`, ISO-8601 UTC derivado do timestamp de servidor do registro.

Suspender executa `updateUser(uid, { disabled: true })` e `revokeRefreshTokens(uid)`. Reativar executa `updateUser(uid, { disabled: false })`. Reativação permite novo login, mas não restaura tokens antigos.

### 18. Registro idempotente de suspensão

- Cada `operationId` é a identidade de um documento em uma coleção administrativa não acessível a clientes.
- Campos mínimos do registro:
  - `adminUid`;
  - `targetUid`;
  - `action`;
  - `reason` normalizado;
  - `status`: `pending`, `succeeded` ou `failed`;
  - `createdAt` de servidor;
  - `completedAt` de servidor quando finalizado;
  - `finalDisabled` quando bem-sucedido;
  - código de falha sanitizado quando falhar.
- Uma transação Firestore cria `pending` somente se o ID estiver livre. Registro existente é comparado com Administrador, alvo, ação e motivo; qualquer divergência retorna `already-exists`/conflito de idempotência.
- Registro `succeeded` retorna o resultado armazenado sem tocar novamente no Auth e sem novo log.
- Registro `failed` reproduz a falha sanitizada armazenada; nova tentativa funcional exige novo `operationId`.
- Registro `pending` provoca reconciliação sob demanda. A Function consulta o Auth:
  - se `reactivate` e a conta já estiver habilitada, finaliza `succeeded`;
  - se `suspend` e a conta já estiver desabilitada, reaplica `revokeRefreshTokens` de forma idempotente e então finaliza `succeeded`;
  - caso contrário, executa a mutação necessária e finaliza.
- Somente Admin SDK cria ou altera esses registros. Depois de `succeeded` ou `failed`, o documento é imutável.
- Não haverá scheduler, Cloud Tasks, fila, retry amplo ou framework genérico de jobs.
- Firebase Auth e Firestore não compartilham transação. Uma interrupção entre a mutação Auth e a finalização permanece como `pending` e é resolvida pela repetição com o mesmo `operationId`.
- Duas operações diferentes concorrentes para o mesmo alvo não são uma transação distribuída; cada uma revalida o estado Auth antes de agir. O painel desabilita a ação local enquanto uma solicitação está em andamento, e esse risco residual deve ser coberto por teste e observabilidade simples, não por um sistema de locks no MVP.

### 19. Suspensão Administrativa e limitação de tokens

- Ao suspender, novos logins falham e futuras renovações de sessão são impedidas após a revogação.
- Um ID token já emitido pode continuar aceito até expirar. A interface e a documentação não usarão “bloqueio instantâneo”.
- Não haverá campo de suspensão consultado por todas as Firestore Rules.
- Motivo é obrigatório na suspensão e reativação e aparece na confirmação final antes do envio.
- Nenhum estado sensível é alterado otimisticamente. Sucesso aparece somente depois da resposta da Function.
- O erro operacional aparece junto da ação; sucesso usa snackbar.
- O painel não permite edição de perfil, e-mail, senha, handle, exclusão, promoção administrativa ou remoção de claim.

### 20. Dashboard

- Usar aggregation queries do Firestore quando suportadas pelo SDK:
  - `count()` de `users` para “Usuários cadastrados”;
  - `count()` de `places` com `status == active`;
  - `count()` de `places` com `status == inactive`.
- O painel informa em texto auxiliar ou ajuda acessível que o primeiro número representa perfis Firestore.
- Atalhos: novo Local Esportivo, locais inativos e busca de Usuário.
- Sem total de suspensos, eventos recentes, chats, feed de auditoria ou gráficos.

### 21. Estados de interface e acessibilidade

- Guard inicial: loading integral sem shell.
- Listas: skeleton somente na primeira carga; paginação mostra indicador no fim da lista sem bloquear conteúdo já carregado.
- Vazio: mensagem contextual e CTA quando aplicável.
- Erro: preserva filtros, página e dados digitados e oferece `Tentar novamente`.
- Cache: leituras cacheadas são exibidas com aviso claro de offline; `SnapshotMetadata.isFromCache`/metadado equivalente determina o estado, não uma lista vazia.
- Formulários: validação inline após interação, resumo dos erros no submit, foco no primeiro erro, valores preservados após erro de rede, validação ou conflito.
- Botões de envio desabilitados durante operação e protegidos contra duplo clique.
- Confirmação de saída para alterações não salvas.
- Contraste mínimo WCAG AA, navegação completa por teclado, ordem de foco coerente, foco visível, labels/semantics para ícones e mensagens que não dependem somente de cor.
- Layout deve funcionar em desktop e larguras menores com sidebar recolhível, sem introduzir bottom navigation.

### 22. App Check

- O painel ativa Firebase App Check Web com provider reCAPTCHA v3 estável.
- Site key e configuração pública são fornecidas por configuração de build; segredos e tokens de debug não entram no Git.
- Localhost/desenvolvimento usam debug provider e token autorizado pelo Console.
- O domínio real do Firebase Hosting é cadastrado/validado antes de ativar enforcement.
- As três Callables usam `enforceAppCheck: true` em produção depois que o painel hospedado emitir tokens válidos.
- Auth, custom claim e Rules continuam obrigatórios; App Check é somente camada adicional.
- Enforcement global do Firestore fica para uma etapa posterior, depois de Android, iOS e Web estarem configurados e as métricas terem sido observadas.
- Replay protection beta não entra no MVP. `operationId` continua sendo o mecanismo de idempotência.

### 23. Firebase Hosting e Functions

- O mesmo projeto `compy-tcc` hospeda painel e Functions.
- Criar um site/target lógico de Hosting chamado `admin` e associá-lo ao projeto.
- O artefato publicado é `admin/build/web`.
- O painel usa URL strategy por path, sem `#`.
- Rewrite `** -> /index.html` suporta refresh e deep links das rotas do GoRouter.
- Usar domínio padrão do Firebase Hosting; domínio customizado fica fora do escopo.
- Deploy será manual e documentado. CI/CD fica fora do escopo.
- O projeto precisa estar no plano Blaze antes do deploy das Functions de segunda geração.
- A documentação recomenda orçamento e alertas de custo antes da implantação.
- Functions, Hosting, Rules e índices devem ser implantáveis de forma seletiva pelos targets oficiais do Firebase CLI.

### 24. Ordem de implantação

1. Confirmar plano Blaze, orçamento/alertas, permissões de deploy e credenciais externas para scripts.
2. Criar o app `admin/`, projeto de Functions e tooling sem ativar produção para usuários finais.
3. Implementar e testar schema, modelos, normalizadores, repositories, Functions e Rules nos emuladores.
4. Executar o backfill idempotente de `users.nameLower` e verificar os perfis.
5. Publicar índices compostos, aguardando estado `READY`.
6. Publicar Rules transitórias expand–contract para `places`, eventos e mensagens.
7. Executar e verificar a migração de `places/parque_do_trabalhador`.
8. Publicar a versão mobile que lê `places` e escreve o contrato novo de eventos/mensagens.
9. Validar fluxos mobile reais, inclusive offline, concorrência, evento legado e Mensagem de Local legada.
10. Criar o site Hosting, registrar o domínio no App Check, publicar o painel e validar login/claim com enforcement ainda controlado em ambiente de teste.
11. Publicar as três Functions em `southamerica-east1` com App Check exigido em produção.
12. Executar smoke test ponta a ponta do painel hospedado.
13. Publicar Rules finais que rejeitam novas escritas legadas.
14. Remover `SportPlace.all/byId` da produção e as avaliações fictícias de local; manter somente fixtures de teste.
15. Observar erros, custos, Functions, Rules e App Check antes de considerar enforcement global do Firestore em uma etapa futura.

### 25. Rollback

- Antes do contract final, o mobile anterior pode ser restaurado enquanto as Rules transitórias ainda aceitam os dois escritores.
- Depois das Rules finais, rollback para um build escritor antigo exige primeiro restaurar temporariamente as Rules de transição. Nunca publicar o build antigo e somente depois descobrir que suas escritas foram bloqueadas.
- A migração de `parque_do_trabalhador` não é revertida por exclusão. O documento é compatível com rollback e pode permanecer sem ser usado pelo build estático.
- Backfill de `nameLower` é aditivo e não precisa ser removido. Rollback de Rules pode simplesmente ignorar o campo.
- Hosting pode voltar a uma release anterior, mas uma release anterior não deve ser restaurada se depender de Functions ou contratos incompatíveis já removidos.
- Functions podem voltar para versão anterior mantendo os registros administrativos. Não apagar logs `pending`, `succeeded` ou `failed` durante rollback.
- Se uma Function nova apresentar falha, pausar a ação na UI e restaurar a versão anterior; não conceder escrita Auth direta ao painel como contingência.
- Índices adicionais podem permanecer durante rollback; removê-los não é necessário e pode prejudicar uma reimplantação rápida.
- Desativação de App Check enforcement é contingência temporária e auditável; Auth e claims nunca são relaxados.

### 26. Critérios de aceite

1. `admin/` compila como Flutter Web independente e não importa código do app mobile.
2. Login não oferece cadastro ou Google Sign-In.
3. Usuário deslogado, sem e-mail verificado ou sem `admin: true` não vê conteúdo administrativo.
4. Deep links administrativos obedecem ao guard antes de iniciar queries.
5. Fechar e reabrir a sessão do navegador exige novo login.
6. Bootstrap aceita somente UID Auth com password provider e e-mail verificado, preserva outras claims e não versiona credenciais.
7. Dashboard mostra as três contagens corretas e explica a semântica de perfis Firestore.
8. Um Administrador cria documento completo e inativo com auto-ID.
9. Nenhum cliente consegue criar local ativo diretamente na criação.
10. Administrador edita conteúdo, ativa, desativa e reativa; usuário comum não escreve.
11. Exclusão de `places` é recusada inclusive para Administrador.
12. Edição com `updatedAt` antigo é recusada e não perde o formulário.
13. Busca/filtros/paginação de lugares funcionam para todas as combinações previstas sem erro de índice.
14. Mobile lista somente ativos; consulta por ID resolve inativo histórico.
15. Erro do stream do mapa não é apresentado como zero pins.
16. Dados cacheados exibem aviso offline; ausência de cache exibe erro e retry.
17. `parque_do_trabalhador` é migrado uma vez, com o mesmo ID e schema válido.
18. Repetir o script sem divergência é no-op; divergência aborta sem sobrescrever.
19. Novos eventos contêm `placeId`, snapshot, coordenadas, geohash e `location` compatível.
20. Rules rejeitam local inexistente, inativo, modalidade incompatível ou snapshot antigo.
21. `sport`, `placeId` e `placeSnapshot` não mudam depois da criação.
22. Evento legado continua legível e pode receber updates legados permitidos sem inventar snapshot.
23. Nova Mensagem de Local contém snapshot mínimo exato e só compartilha local ativo.
24. Mensagem legada somente com `placeId` continua legível e possui fallback quando irresolúvel.
25. Criação de evento e compartilhamento falham offline sem enfileirar e preservam conteúdo preparado.
26. Pesquisa de Usuários executa somente o tipo explicitamente selecionado.
27. Prefixos de Nome e Handle são paginados em blocos de 20; UID e E-mail são exatos.
28. Uma única chamada em lote obtém estado Auth para cada página.
29. Falha do lote produz `Estado indisponível`; UID omitido produz `Conta não encontrada`.
30. Conta Auth sem perfil mostra `Perfil não encontrado` e continua administrável se não for admin.
31. Perfil sem conta Auth não oferece suspensão/reativação.
32. Nenhuma Callable aceita usuário sem autenticação, sem claim ou sem App Check quando enforcement estiver ativo.
33. Nenhuma Callable expõe dados além de seu contrato.
34. `setUserSuspension` impede autoação e alvo administrativo.
35. Suspensão desabilita Auth, revoga refresh tokens e registra motivo; reativação habilita Auth.
36. A UI não promete invalidação instantânea de token já emitido.
37. Repetição de `succeeded` devolve o mesmo resultado sem novo registro.
38. Repetição de `failed` devolve a falha e exige novo ID para nova tentativa.
39. Repetição de `pending` reconcilia Auth e finaliza, incluindo nova revogação idempotente no caso de suspensão.
40. Mesmo `operationId` com parâmetros diferentes é rejeitado.
41. Registros finalizados não podem ser alterados e nenhum cliente pode acessá-los diretamente.
42. Painel hospedado suporta refresh em todas as rotas por rewrite de SPA.
43. Layout funciona com sidebar ampla/recolhida, teclado, foco visível e contraste WCAG AA.
44. Rules finais rejeitam novas escritas legadas sem quebrar leitura de histórico.
45. Todos os testes automatizados e smoke tests definidos nesta spec passam antes do contract final.

## Testing Decisions

### Filosofia e seams

- Testar comportamento observável e contratos, não métodos privados, widgets internos ou a ordem acidental de chamadas.
- Usar o menor conjunto de seams de alto nível:
  1. Firestore Rules no emulador para autorização, schema, invariantes e concorrência observável no commit;
  2. handlers das Callable Functions com gateways injetáveis para Auth/Firestore e testes de integração no emulator suite;
  3. contratos de repository/use case para mobile e painel;
  4. guards/rotas e fluxos completos de página para UI;
  5. comandos idempotentes dos scripts como seam de tooling.
- Preferir o prior art existente: testes Node das Rules contra o emulador, testes Dart de repositories/modelos, testes do redirect do GoRouter e testes de mappers tolerantes a documentos legados.

### Firestore Rules

- `places`: get/list de ativo e inativo por papel; query sem filtro ativo recusada para usuário comum; CRUD admin; create sempre inativo; delete negado; whitelist; campos extras; tipos; limites; UFs; CEP; HTTPS; GeoPoint; modalidades; duplicatas; primarySport; timestamps e createdAt imutável.
- Eventos em Rules transitórias e finais: escritor antigo durante expand, escritor novo, local ausente/inativo, sport incompatível, snapshot divergente, top-level coordinates divergente, imutabilidade de sport/placeId/snapshot, joins atuais e documentos legados.
- Mensagens: texto comum, snapshot válido, local inativo, snapshot divergente, membro/não membro, senderId, legado somente com placeId durante transição e rejeição de nova escrita legada depois do contract.
- Usuários: criação com `nameLower`, backfill/transição, handle e createdAt imutáveis, atualização de favoriteSports, dados privados inacessíveis ao painel.
- Registros administrativos: toda leitura/escrita por SDK cliente negada, inclusive com claim admin.
- `ratings`: `targetType: place` recusado; alvos ainda suportados preservam o comportamento atual.
- Queries reais devem ser executadas nos testes; não basta testar `get` isolado, porque Rules são dependentes da forma da query.

### Callable Functions

- Matriz de autenticação: sem Auth, sem claim, claim falsa, admin válido e App Check ausente/inválido/válido.
- `getAdminUserAuthDetails`: UID, e-mail normalizado, ambos, nenhum, campo extra, inexistente, conta com múltiplos providers, conta sem e-mail e minimização do retorno.
- `getAdminUsersAuthStatus`: limites 0/1/20/21, duplicatas, UID inválido, encontrados e ausentes, ordem e retorno mínimo.
- `setUserSuspension`: inputs, motivo nos limites, UUID, self, alvo admin, alvo inexistente, estado já desejado, suspend e reactivate.
- Idempotência: succeeded repetido, failed repetido, parâmetros divergentes, pending antes/depois da mutação Auth e falha entre disable e revoke.
- Confirmar que suspensão chama disable e revoke; reconciliação pending suspensa reaplica revoke antes de finalizar.
- Testar que falhas retornadas são sanitizadas e não incluem stack, token ou detalhes internos.
- Usar Auth/Firestore emulators quando suportarem o comportamento; para revogação e falhas intermediárias, usar gateways testáveis e mocks/fakes controlados.

### Painel Flutter Web

- Unit tests para normalizador, formatador de endereço, modelos, validação de schema, serialização, cursores e mapeamento de erros.
- Guard de rotas como função pura, cobrindo todas as combinações de auth/claim/e-mail/loading/error/deep link e ausência de loops.
- Widget tests para shell responsivo, login, unauthorized, dashboard, estados de lista, filtros, formulário, confirmação de saída e ações sensíveis.
- Testes de acessibilidade para labels, foco, navegação por teclado, contraste do tema e ausência de informação somente por cor.
- Testes de controller para paginação, mudança de filtro, atualização real-time, cache/offline, conflito `updatedAt`, preservação de formulário e bloqueio de duplo submit.
- Integração com emuladores para CRUD de local e listagem de usuários; smoke test hospedado separado para Auth, claims, App Check, Hosting e Functions reais.

### Mobile

- Modelo/mapper de Local Esportivo para schema completo e rejeição/tolerância controlada de dados inválidos.
- Repository Firestore: stream ativo, modalidade, ordem, get por ID inativo, metadado de cache, erro e retry.
- Mapa: loading, vazio, offline com cache, erro sem cache, busca local e local selecionado desativado.
- Evento: serialização nova, leitura legada, transação online, snapshot exato, conflito, local desativado e preservação dos demais campos.
- Mensagem: snapshot novo, legado somente com ID, fallback genérico, dados atuais preferidos e inativo histórico.
- Reescrever testes atuais acoplados a `SportPlace.all/byId`; fixtures podem conservar o mesmo local sem servir como fonte de produção.
- Rodar toda a suíte Flutter existente para evitar regressões em auth, eventos, chat, perfil e navegação.

### Scripts e implantação

- Bootstrap: dry-run, UID ausente, provider incorreto, e-mail não verificado, claim existente e preservação de claims.
- Migração de local: create, no-op idempotente, divergência abortada, credencial ausente e validação pós-escrita.
- Backfill de perfil: perfis válidos, já migrados, nome acentuado, nome ausente e execução repetida.
- Validar sintaxe e deploy dry-run/configuração de Rules, índices, Functions e Hosting antes da produção.
- Smoke tests manuais documentados devem cobrir login admin, deep link, Dashboard, CRUD/status de local, busca de cada tipo, conta sem perfil, perfil sem conta, suspensão, reativação e limitação de token já emitido.

## Out of Scope

- Gestão de Eventos Esportivos pelo painel.
- Gestão de chats ou Mensagens de Local pelo painel.
- Denúncias e moderação de conteúdo.
- Analytics avançado, gráficos e eventos recentes no Dashboard.
- Feed ou tela geral de auditoria.
- Múltiplos níveis administrativos, roles compostas ou gestão de Administradores.
- Edição administrativa de Perfil de Usuário, handle, e-mail ou senha.
- Redefinição de senha pelo Administrador.
- Exclusão de Conta de Usuário pelo painel.
- Exclusão física de Local Esportivo pelo painel.
- Banimento permanente ou invalidação imediata de todo ID token.
- Cloud Function para CRUD comum de `places`.
- Cloud Function para criação de Evento Esportivo.
- Estado de suspensão duplicado no Firestore e consultado por todas as Rules.
- Upload de imagem, Firebase Storage, galeria ou processamento de imagem.
- Geocodificação automática ou bounding box rígida de Taquara.
- Sistema real de avaliações de locais ou edição manual de avaliações.
- Cache persistente próprio, fila offline administrativa ou sistema genérico de sincronização.
- Scheduler, Cloud Tasks ou framework genérico de jobs para operações administrativas.
- Replay protection beta do App Check.
- Enforcement global imediato do App Check no Firestore.
- CI/CD, domínio customizado e infraestrutura fora do Firebase atual.
- Package compartilhado, reorganização em monorepo ou refatoração ampla do mobile além dos contratos afetados.
- Remoção do campo textual `location` dos eventos.
- Migração destrutiva de eventos ou mensagens legados.

## Further Notes

### Riscos e dependências externas

- O plano Blaze é necessário para implantar Functions. Orçamento e alertas devem existir antes do deploy.
- A disponibilidade do painel depende de Firebase Auth, Firestore, Functions, Hosting, App Check e reCAPTCHA v3. O smoke test real é indispensável porque os emuladores não reproduzem integralmente App Check e Hosting.
- Custom claims só chegam ao cliente após renovação do ID token; o bootstrap precisa instruir novo login.
- Suspensão não invalida instantaneamente um ID token já emitido. O risco é aceito e deve permanecer explícito na interface e documentação.
- Auth e Firestore não são transacionais entre si. O registro idempotente reduz o risco, mas operações diferentes concorrentes para o mesmo alvo ainda exigem revalidação e observação.
- Direct CRUD de `places` confia em Administradores autenticados e nas Rules. A linguagem de Rules não reproduz integralmente o normalizador pt-BR; testes compartilhados e tooling confiável evitam drift.
- URLs de imagem externas podem ficar indisponíveis. O mobile e o painel devem manter placeholder visual, sem aceitar URL não HTTPS nem interpretar falha de download como schema inválido.
- O endereço e a imagem iniciais de `parque_do_trabalhador` devem ser conferidos antes da migração. O ID e as coordenadas atuais não mudam.
- O contract final interrompe escritas de builds antigos. A ordem de deploy e o plano de rollback são parte obrigatória da entrega.
- As combinações de filtro de `places` geram sete índices. Qualquer novo filtro combinado aumenta custo de manutenção e deve ser avaliado antes de entrar no escopo.
- O Dashboard não conta contas Auth sem perfil; essa diferença é deliberada e deve estar visível ao Administrador.
- O manual de Rules atualmente menciona JDK incompatível em uma máquina específica. A implementação deve documentar o pré-requisito genericamente e garantir JDK 21+ no ambiente que executará a suíte.

### Consistência arquitetural

- Esta spec respeita o glossário de `CONTEXT.md`: Administrador, Painel Administrativo, Usuário, Conta de Usuário, Perfil de Usuário, Suspensão Administrativa, Local Esportivo, Local Esportivo Inativo, Evento Esportivo e Mensagem de Local.
- Respeita o ADR que separa CRUD direto de `places` de informações privilegiadas e mutações de Conta de Usuário via Callables/Admin SDK.
- Não descreve `admin/`, Functions, Hosting, `places`, novos campos ou novos índices como existentes; todos são estado alvo.
- A divergência entre o catálogo estático atual e a fonte Firestore aprovada é tratada pela migração expand–contract, não por fallback permanente em produção.
- A divergência entre regras atuais de perfil e a busca administrativa é tratada por backfill de `nameLower` e endurecimento gradual de `handle`/`createdAt`.
- A permissão atual de avaliação com `targetType: place` será removida para alinhar as Rules à inexistência de avaliações reais de Local Esportivo.

### Definição de pronto para decomposição

- A arquitetura, os contratos, as fronteiras de segurança, os índices, os estados de UI, a migração, os testes, a implantação e o rollback estão definidos.
- A próxima etapa pode decompor esta spec com `to-tickets` sem reabrir decisões arquiteturais.
- Nenhum ticket é criado por esta publicação.

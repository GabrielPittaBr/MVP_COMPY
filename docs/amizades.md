# Sistema de amizades — COMPY

Implementado em `feature/sistema-amizades`, a partir de `origin/develop`
(`0003489`, 02/11/2026). A correção local dos detalhes (`ddd4c26`) foi
preservada em sua própria branch; não foi misturada, integrada ou publicada.

## Contrato e arquitetura

A feature `lib/features/friends/` contém entidade Equatable, interface de
repositório, casos de uso, datasource Firestore, store em memória, providers,
ações e página. Reutiliza os perfis públicos, UserAvatar, autenticação,
Riverpod e GoRouter. Não exige amizade para enviar mensagens e não altera
eventos, autenticação, contatos privados ou o esquema de `users/{uid}`.

```text
friendships/{uidMenor}:{uidMaior}
  members:     [uidMenor, uidMaior]  // ordenação lexicográfica
  senderId:    UID do remetente
  status:      "pending" | "accepted"
  requestedAt: timestamp do servidor
  acceptedAt:  timestamp do servidor (apenas em accepted)
```

O ID usa UIDs, nunca nomes ou handles. O contrato aceita os UIDs gerados pelo
Auth do aplicativo: 1–128 caracteres ASCII alfanuméricos, sublinhado ou hífen.
Dois UIDs iguais são recusados. O separador `:` não pode fazer parte deles,
evitando colisões como as que uma concatenação ingênua com sublinhado teria.
Imports de contas com UIDs customizados fora desse contrato exigem avaliação
prévia, sem mudar IDs de usuários existentes.

Não são gravados dados de apresentação ou dados privados nas relações.
Perfis antigos sem relações começam com listas vazias; o antigo
`UserProfile.friends` permanece compatível com fixtures, mas não é fonte da UI.

| Ação | Autor | Antes | Depois |
|---|---|---|---|
| Enviar | Remetente, com os dois perfis existentes | Ausente | pending |
| Aceitar | Destinatário | pending | accepted |
| Recusar | Destinatário | pending | Documento excluído |
| Cancelar | Remetente | pending | Documento excluído |
| Desfazer | Qualquer participante, com confirmação na UI | accepted | Documento excluído |

Envio e demais operações usam transações. Um envio repetido ou cruzado não
reescreve uma relação existente e não aceita automaticamente uma solicitação.
Os outros comandos conferem remetente, estado e data da solicitação esperada,
evitando que uma ação antiga atinja uma solicitação nova. Repetições de remoção
de documento já ausente não fazem nova escrita. Aceite já confirmado da mesma
solicitação também não reescreve timestamps. Transações precisam do servidor:
offline, a operação falha e pode ser repetida; não há aceite otimista.

## Regras e consultas

`firestore.rules` valida campos exatos, tipos, par canônico, autoria e
timestamps. Create exige pending e perfis existentes. Update permite apenas
pending → accepted pelo destinatário, alterando status/acceptedAt e mantendo
identidade e requestedAt. Terceiros, anônimos, remetente tentando aceitar,
relações prontas forjadas, campos extras e trocas de membros são recusados.

A exclusão está limitada a participantes de friendships. Em pending, a
mesma exclusão representa cancelamento para o remetente e recusa para o
destinatário; os casos de uso também validam essa direção. Em accepted,
qualquer participante remove. Não foram relaxadas permissões de outras
coleções. Get de par ausente é autorizado só aos UIDs do ID canônico,
necessário para a transação inicial; list exige consulta pelo próprio membro:

```dart
collection('friendships').where('members', arrayContains: uid).snapshots()
```

Não há índices compostos novos: a consulta e a limpeza usam o índice
automático de array de `members`. `firestore.indexes.json` não mudou.

Há uma assinatura compartilhada dos **metadados do grafo privado da sessão**,
não uma consulta de relação por usuário exibido ou pesquisado. Isso permite
contagens completas e atualização simétrica sem denormalização. A consulta
de metadados não é paginada; é uma decisão para o volume do MVP. Em contas com
muitas relações, todas elas terão custo de leitura inicial. Antes de ampliar
esse volume, avaliar paginação remota por estado e agregados, preservando a
correção do estado do perfil de qualquer par.

Perfis não são baixados em massa: prévia de até seis, lista vertical lazy em
etapas de 25, assinatura `publicUserSummaryProvider(uid)` compartilhada por
UID montado. `autoDispose` libera recursos sem consumidores; TickerMode
suspende as áreas ocultas mantidas pelo indexedStack/Navigator, preservando
a seleção da aba da página. Troca de conta reinicia a consulta por UID.

## Interface

O perfil público mantém Mensagem e acrescenta Adicionar amigo, Solicitação
enviada/Cancelar, Responder solicitação/Aceitar/Recusar ou Amigos/Desfazer.
No próprio perfil não há controles para si mesmo. Falhas de leitura oferecem
nova tentativa; falhas de escrita preservam a relação e permitem repetir.
O controller por UID bloqueia operações simultâneas e conclui gravações mesmo
se o widget for desmontado. Não apresenta amizade confirmada antes do backend.

A seção de amigos do perfil mostra contagem, avatares reais, vazio, Ver todos
e contagem de recebidas com acesso direto. `/profile/amigos` tem abas Amigos,
Recebidas e Enviadas; `?tab=1` abre recebidas. A linha de apresentação inteira
abre o perfil público, sem conflito com as ações abaixo. Nomes e handles podem
quebrar linha. Nome e avatar acompanham o perfil atual; perfil ausente fica
indisponível, sem impedir recusar/cancelar/desfazer a relação por UID.

Não foram adicionados notificações, FCM ou requisitos novos ao Chat. O fluxo
completo de solicitações fica no perfil, conforme o escopo do MVP.

## Exclusão de contas

O app apaga o próprio perfil em `AuthRemoteDataSource._deleteUserDocuments`.
O painel apaga perfil e subcoleções em `deleteUserAccount`, após desabilitar
a conta, seguindo a ADR 0003. Ambos continuam usando seus fluxos existentes.

A nova Function `onProfileDeletedFriendships` observa delete de
`users/{uid}`, na região southamerica-east1. Exclui pending e accepted desse
UID em lotes de 200, com Admin SDK, sem tocar eventos, mensagens ou avaliações.
É idempotente e possui retry. Se um perfil do mesmo UID já existe quando
executa, não apaga suas relações por causa de um evento atrasado.

A limpeza é assíncrona: até ela terminar, um relacionamento pode aparecer
com Perfil indisponível. Create e aceite exigem perfis existentes; o outro
participante ainda pode remover a relação. Exclusões anteriores à publicação
do gatilho não geram eventos retroativos. Relações órfãs antigas podem ser
removidas pela contraparte ou por uma limpeza administrativa autorizada,
consultando exclusivamente `friendships.where('members', 'array-contains', uid)`.
Não executamos migrações, exclusões reais ou limpeza de produção.

## Validação local

Na integração com a correção visual dos eventos, a combinação passou em
**509 testes Flutter**, mantendo 219 testes de regras e 98 de Functions.
A [auditoria para a FEINTEC](validacao-feintec-2026.md) registra a comparação
somente leitura com o Firebase publicado e o build Android local. Os resultados
abaixo são os da implementação original, anterior à integração.

- `flutter test --no-pub`: **500 aprovados**, incluindo 17 testes novos da
  feature (domínio, mapper, repositórios, providers e widgets).
- `dart analyze`: código 0, sem erros/warnings; 10 informações preexistentes.
- `npm test --prefix tools/firestore-rules-tests`: **219 aprovados**,
  com Auth, Firestore e Storage em `demo-compy`. Inclui duas contas reais no
  Auth local, envio, leitura, aceite e remoção persistidos, consultas de
  envolvidos e negações, par único, envios cruzados e perfis ausentes.
- `npm test --prefix functions`: **98 aprovados**, incluindo lotes de limpeza,
  repetição, retry após falha e proteção contra evento atrasado.
- `npm run lint --prefix functions` e `git diff --check`: aprovados.

O Flutter foi chamado pelo alias curto existente do SDK, devido ao hook
objective_c em caminhos Windows com espaços. Para os emuladores, usamos JDK
21 local e JAVA_TOOL_OPTIONS com diretório temporário de socket, somente no
processo de teste, sem alterar configurações permanentes.

## Publicação — 03/11/2026

Até esta data as regras no ar eram as de 31/10, sem `friendships`: toda
leitura e escrita de amizade voltava `PERMISSION_DENIED` e a UI mostrava o
erro de carregamento (issue #34). Publicamos a partir da `develop`, depois de
passarem as regras (219), as Functions (98, com lint) e o `flutter test` (509):

```powershell
firebase deploy --project compy-tcc --only firestore:rules
firebase deploy --project compy-tcc --only functions:administrative:onProfileDeletedFriendships --force
```

- **Regras:** ruleset `7631a13b-f7df-48e2-9f24-79ce620874c2`, de
  `2026-11-03T12:53:15Z`, idêntico ao `firestore.rules` versionado. Em relação
  ao anterior, só mudaram o bloco `friendships` e o comentário inicial.
- **Function:** `onProfileDeletedFriendships` `ACTIVE`, 2ª geração, em
  southamerica-east1, com gatilho `document.v1.deleted` em `users/{uid}` e
  `RETRY_POLICY_RETRY`. O `--force` só confirma o aviso de retry, que o CLI
  exige fora do modo interativo; o filtro `--only` deixa as outras Functions
  fora do deploy.
- **Índices:** nada a publicar; a consulta usa o índice automático de `members`.

A v1.0.0 não tem a feature, que chega a quem baixa pelo link na versão
seguinte. Continua pendente a validação no aparelho: duas contas em dois
Androids para enviar/cancelar, aceitar/recusar, desfazer, reabrir o app e
trocar de conta, e a limpeza das relações depois de excluir uma conta pelo app
e pelo painel.

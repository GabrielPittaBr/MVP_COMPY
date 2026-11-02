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

## Publicação pendente — não executada

Antes de distribuir o app com esta feature:

1. Revisar e publicar o `firestore.rules` versionado. Com as regras anteriores,
   as consultas à coleção nova são negadas e a UI mostra erro, sem inventar amigos.
2. Publicar **somente a Function nova** `onProfileDeletedFriendships`, no
   codebase `administrative`, região southamerica-east1. Confirmar gatilho de
   exclusão de `users/{uid}`, permissões de execução e política de retry.
   Não é necessário alterar callables administrativas existentes.
3. Preservar o índice automático de array de members. Não há índice novo a
   publicar neste commit.
4. Gerar um APK contendo esta branch em etapa própria e validar com duas contas
   no Android: enviar/cancelar, aceitar/recusar, desfazer, encerrar/reabrir app,
   troca de conta, falha de conexão e atualização de nome/foto.
5. Validar também a execução end-to-end do gatilho após exclusão pelo app e
   pelo painel, incluindo retry. Aqui o handler foi testado com gateway local;
   o fluxo Auth/Firestore real usou emuladores, sem emular o gatilho de Functions.

A validação local não equivale à publicação nem à homologação no aparelho.
Main, assinatura, Google Sign-In, configuração Firebase e produção não foram
alterados. Não houve push, merge ou deploy.

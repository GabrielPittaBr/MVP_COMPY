# Identidade atual nas conversas

Correção de 29/10/2026, na branch `fix/avatar-atualizado-chat`.

## Causa

`ChatRemoteDataSource.createConversation` grava `memberSummaries` uma vez.
As regras preservam esse campo nos updates; enviar mensagens atualiza apenas
a prévia, o horário e as não lidas. `ConversationMapper` lia nome e foto desse
snapshot, e lista, cabeçalho e balões usavam `conversation.peer` diretamente.
O stream de mensagens e o da primeira página não acompanham `users/{uid}`.
Assim, até reabrir o aplicativo recuperava a URL histórica.

O Storage já gera `avatar_<millis>.jpg` a cada envio. A URL nova tem uma chave
de cache diferente: limpar imagens não resolveria a URL antiga salva na
conversa. Também faltava reconhecer o placeholder de remoção em `UserAvatar`,
que tentava baixar a imagem de `placehold.co`.

## Estratégia

- `conversationPeerProvider` resolve a apresentação usando o
  `publicUserSummaryProvider(uid)` existente, que passa pelo repositório de
  perfis e pelo stream Firestore `users/{uid}`.
- Cada UID tem uma assinatura compartilhada entre os componentes montados
  de eventos, lista e sala. A lista constrói linhas sob demanda, inclusive a
  área de cache de rolagem do Flutter. A sala resolve uma vez e passa a mesma
  identidade ao cabeçalho e aos balões; mensagens não criam listeners.
  `autoDispose` libera a assinatura quando perde o último consumidor.
- A apresentação usa o perfil atual inteiro. Foto vazia ou placeholder em
  um perfil existente significa remoção e nunca recupera a foto histórica.
  `UserAvatar` desenha o ícone local sem download de placeholder.
- Carregamento, perfil ausente e erro sem valor anterior usam o snapshot;
  quando Riverpod preserva o último valor disponível, ele continua visível
  durante uma falha. Isso mantém a conversa utilizável.
- O UID de `members` prevalece sobre o `id` embutido nos resumos. Se não há
  resumo, ainda podemos buscar o perfil e navegar pelo UID. Documentos sem
  `members` usam a chave do resumo; sem ambos, mostram identidade desconhecida
  e não tentam buscar um perfil sem UID conhecido.
- Ao salvar foto, `AvatarController` também invalida a leitura do próprio
  perfil público e os resultados de busca, além do perfil proprietário.
  O stream compartilhado recebe a mudança naturalmente, sem reiniciá-lo.

Os snapshots continuam históricos, como decidido no roadmap. Não mudamos o
schema, as regras, o repositório de mensagens ou a persistência do chat.
`MessageMapper` continua preservando `senderId`; as mensagens mantêm texto,
ordem, remetente e contexto de locais compartilhados.

## Verificação

`test/features/chat/chat_profile_identity_test.dart` usa dois containers
Riverpod independentes, A e B, com `ProfileRepositoryImpl` real e dublês dos
documentos/streams do SDK. A interface de A monta a lista e a sala existentes;
B salva fotos pelo `AvatarController` real.

- Foto inicial, duas substituições, remoção e nova foto aparecem no perfil
  próprio de B, na leitura pública de B, na linha de A, no cabeçalho e nos
  avatares de três mensagens existentes.
- Mudança de nome aparece em A, e o atalho do cabeçalho continua abrindo o
  perfil pelo mesmo UID.
- Recriamos o container e a interface de A, mantendo os dados simulados:
  nome e foto atuais reaparecem sem recriar a conversa.
- Perfil ausente, falha de stream, foto vazia e conversa legada são cobertos.
  Os testes conferem o fallback, a liberação da assinatura e uma única
  chamada de assinatura para o UID, mesmo entre snapshots diferentes.
- Mappers cobrem UID divergente, resumos ausentes/malformados e legado sem
  `members`. Os testes existentes de mensagens, paginação, perfil e eventos
  continuam exercitando os respectivos contratos.

Resultado: `flutter test --no-pub` passou com **443 testes**. Usamos o alias
8.3 existente `C:/Users/BERNAR~1/develop/flutter/bin/flutter.bat` para contornar
o hook `objective_c`, que falha com espaços no caminho do SDK Windows.
`dart analyze` terminou com código 0, sem erros ou warnings e com os mesmos
10 diagnósticos informativos preexistentes em arquivos fora desta correção.
`git diff --check` também passou.

## Arquivos alterados

- `lib/features/chat/data/mappers/conversation_mapper.dart`: UID canônico e
  leitura legada dos resumos.
- `lib/features/chat/presentation/providers/chat_providers.dart`: resolução
  reativa da identidade apresentada.
- `lib/features/chat/presentation/widgets/conversation_tile.dart` e
  `lib/features/chat/presentation/pages/chat_room_page.dart`: consumo da
  identidade atual na linha, no cabeçalho e nos balões.
- `lib/features/profile/presentation/providers/profile_providers.dart`:
  invalidação das leituras após salvar foto e documentação do compartilhamento.
- `lib/shared/widgets/user_avatar.dart`: placeholder local para foto removida.
- `lib/core/services/avatar_storage.dart`: comentário atualizado sobre a
  preservação de fotos históricas, sem mudança no upload.
- `test/features/chat/chat_profile_identity_test.dart`: dois clientes,
  providers, componentes e persistência simulada.
- `test/features/chat/conversation_mapper_test.dart`,
  `test/features/chat/conversation_tile_test.dart`,
  `test/features/chat/conversations_page_test.dart` e
  `test/shared/widgets/user_avatar_test.dart`: regressões e isolamento dos
  streams nos testes existentes.
- Este registro, `docs/roadmap.md` e
  `docs/caderno_de_campo/Anotacoes10292026.md`: diagnóstico, decisão e validação.

## Limites

A validação com A e B foi automatizada com persistência simulada; não houve
login em duas contas reais, emulador Firebase ou alteração de produção nesta
tarefa. Os testes conferem as URLs entregues às imagens e os placeholders,
sem baixar fotos reais. CORS, conectividade e permissões de Storage continuam
dependendo do ambiente. Offline, a atualização depende do perfil disponível
no cache do Firestore; o snapshot histórico pode aparecer até a sincronização.
URLs externas cujo conteúdo muda sem mudar o endereço continuam sujeitas ao
cache normal. Uploads do COMPY já evitam isso com nomes novos.
